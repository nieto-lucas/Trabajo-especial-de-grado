#include "function/reachable_by.hpp"

#include <memory>
#include <unordered_map>
#include <unordered_set>

#include "catalog/catalog.h"
#include "catalog/catalog_entry/node_table_catalog_entry.h"
#include "catalog/catalog_entry/table_catalog_entry.h"
#include "common/exception/binder.h"
#include "common/types/types.h"
#include "common/vector/value_vector.h"
#include "extension/extension.h"
#include "function/binary_function_executor.h"
#include "function/scalar_function.h"
#include "graph/graph_entry.h"
#include "graph/on_disk_graph.h"
#include "main/client_context.h"
#include "transaction/transaction.h"

using namespace lbug::common;
using namespace lbug::function;

namespace lbug {
namespace loern_extension {

const std::vector<std::string> FLOW_RELS = {
    "REACHING_DEF", "ARG_TO_PARAM", "RET_TO_CALL"
};

struct NodeKeyHash {
    size_t operator()(const nodeID_t& n) const {
        return std::hash<uint64_t>()(n.offset)^(std::hash<uint64_t>()(n.tableID) << 1);
    }
};

using NodeSet = std::unordered_set<nodeID_t, NodeKeyHash>;

using ScanState = std::pair<graph::GraphRelInfo, std::unique_ptr<graph::NbrScanState>>;

struct ReachBindData final : public FunctionBindData {
    main::ClientContext* ctx;
    // Estado lazy, propio de cada copia (cada evaluador/hilo tiene la suya).
    std::unique_ptr<graph::OnDiskGraph> graph;
    std::unordered_map<table_id_t, std::vector<ScanState>> scanStates;
    std::unordered_map<nodeID_t, NodeSet, NodeKeyHash> closureCache;

    ReachBindData(std::vector<LogicalType> params, main::ClientContext* ctx)
        : FunctionBindData{std::move(params), LogicalType::BOOL()}, 
          ctx{ctx} {}

    std::unique_ptr<FunctionBindData> copy() const override {
        return std::make_unique<ReachBindData>(LogicalType::copy(paramTypes), ctx);
    }

    void initGraph() {
        if (graph) {
            return;
        }
        auto catalog = catalog::Catalog::Get(*ctx);
        auto tx = transaction::Transaction::Get(*ctx);
        std::vector<catalog::TableCatalogEntry*> nodes, rels;
        
        for (auto* entry : catalog->getNodeTableEntries(tx, false)) {
            nodes.push_back(entry);
        }
        for (auto& name : FLOW_RELS) {
            if (catalog->containsTable(tx, name)) {
                rels.push_back(catalog->getTableCatalogEntry(tx, name));
            }
        }
        graph = std::make_unique<graph::OnDiskGraph>(
            ctx, 
            graph::NativeGraphEntry(nodes, rels)
        );
    }

    auto& statesFor(table_id_t tableID) {
        auto it = scanStates.find(tableID);
        if (it != scanStates.end()) {
            return it->second;
        }
        auto& visit = scanStates[tableID];
        for (auto& info : graph->getRelInfos(tableID)) {
            auto state = graph->prepareRelScan(
                *info.relGroupEntry, 
                info.relTableID, 
                info.dstTableID,
                std::vector<std::string>{}
            );
            visit.emplace_back(info, std::move(state));
        }
        return visit;
    }

    // Clausura hacia adelante desde src (incluye a src: reachableBy cuenta sink == source).
    const NodeSet& closure(nodeID_t src) {
        auto it = closureCache.find(src);
        if (it != closureCache.end()) {
            return it->second;
        }
        initGraph();
        NodeSet seen{src};
        std::vector<nodeID_t> frontier{src};
        while (!frontier.empty()) {
            std::vector<nodeID_t> next;
            for (auto node : frontier) {
                for (auto& [info, state] : statesFor(node.tableID)) {
                    for (auto chunk : graph->scanFwd(node, *state)) {
                        chunk.forEach([&](auto nbrs, auto /*props*/, auto i) {
                            if (seen.insert(nbrs[i]).second) {
                                next.push_back(nbrs[i]);
                            }
                        });
                    }
                }
            }
            frontier = std::move(next);
        }
        return closureCache.emplace(src, std::move(seen)).first->second;
    }
};

struct ReachOp {
    static void operation(
        internalID_t& src, 
        internalID_t& sink, 
        uint8_t& result, 
        void* dataPtr
    ) {
        auto* bd = static_cast<ReachBindData*>(dataPtr);
        result = bd->closure(src).contains(sink);
    }
};

struct ReachWrapper {
    template<typename L, typename R, typename RES, typename OP>
    static void operation(
        L& left, R& right, RES& result, 
        ValueVector*, ValueVector*, ValueVector*,
        uint64_t, void* dataPtr
    ) {
        OP::operation(left, right, result, dataPtr);
    }

    // Variante usada por BinaryFunctionExecutor::select (ruta rápida de WHERE).
    template<typename L, typename R, typename OP>
    static void operation(
        L& left, R& right, uint8_t& result, 
        ValueVector*, ValueVector*,
        void* dataPtr
    ) {
        OP::operation(left, right, result, dataPtr);
    }
};

static ValueVector& idVector(const std::shared_ptr<ValueVector>& node) {
    auto idx = StructType::getFieldIdx(node->dataType, InternalKeyword::ID);
    return *StructVector::getFieldVector(node.get(), idx);
}

static std::unique_ptr<FunctionBindData> bindFunc(
    const ScalarBindFuncInput& input
) {
    std::vector<LogicalType> params;
    for (auto& arg : input.arguments) {
        params.push_back(arg->getDataType().copy());
    }
    return std::make_unique<ReachBindData>(std::move(params), input.context);
}

static void execFuncNodes(
    const std::vector<std::shared_ptr<ValueVector>>& params,
    const std::vector<SelectionVector*>& sel, 
    ValueVector& result, 
    SelectionVector* resultSel,
    void* dataPtr
) {
    BinaryFunctionExecutor::executeSwitch
    <internalID_t, internalID_t, uint8_t, ReachOp, ReachWrapper>(
        idVector(params[0]), sel[0], 
        idVector(params[1]), sel[1], 
        result, resultSel,
        dataPtr
    );
}

static bool selectFuncNodes(
    const std::vector<std::shared_ptr<ValueVector>>& params, 
    SelectionVector& selVector,
    void* dataPtr
) {
    auto result = BinaryFunctionExecutor::select
        <internalID_t, internalID_t, ReachOp, ReachWrapper>(
            idVector(params[0]), 
            idVector(params[1]), 
            selVector, 
            dataPtr
    );
    return result;
}

static void execFuncIds(
    const std::vector<std::shared_ptr<ValueVector>>& params,
    const std::vector<SelectionVector*>& sel, 
    ValueVector& result, 
    SelectionVector* resultSel,
    void* dataPtr
) {
    BinaryFunctionExecutor::executeSwitch
    <internalID_t, internalID_t, uint8_t, ReachOp, ReachWrapper>(
        *params[0], sel[0], 
        *params[1], sel[1], 
        result, resultSel,
        dataPtr
    );
}

static bool selectFuncIds(
    const std::vector<std::shared_ptr<ValueVector>>& params, 
    SelectionVector& selVector,
    void* dataPtr
) {
    auto result = BinaryFunctionExecutor::select
        <internalID_t, internalID_t, ReachOp, ReachWrapper>(
            *params[0], 
            *params[1], 
            selVector, 
            dataPtr
    );
    return result;
}

function_set ReachableByFunction::getFunctionSet() {
    function_set set;
    
    auto func_nodes = std::make_unique<ScalarFunction>(
        name,
        std::vector<LogicalTypeID>{LogicalTypeID::NODE, LogicalTypeID::NODE},
        LogicalTypeID::BOOL, 
        execFuncNodes, 
        selectFuncNodes
    );
    func_nodes->bindFunc = bindFunc;
    set.push_back(std::move(func_nodes));

    auto func_ids = std::make_unique<ScalarFunction>(
        name,
        std::vector<LogicalTypeID>{LogicalTypeID::INTERNAL_ID, LogicalTypeID::INTERNAL_ID},
        LogicalTypeID::BOOL,
        execFuncIds,
        selectFuncIds
    );
    func_ids->bindFunc = bindFunc;
    set.push_back(std::move(func_ids));

    return set;
}

} // namespace loern_extension
} // namespace lbug