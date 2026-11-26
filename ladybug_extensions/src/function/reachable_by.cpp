#include "function/reachable_by.hpp"

#include <deque>
#include <array>
#include <vector>
#include <memory>
#include <unordered_map>

#include "catalog/catalog.h"
#include "catalog/catalog_entry/node_table_catalog_entry.h"
#include "catalog/catalog_entry/table_catalog_entry.h"
#include "common/exception/binder.h"
#include "common/types/internal_id_util.h"
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

// Relaciones de flujo de datos para caminos reachable_by 
static constexpr std::array<const char*, 3> FLOW_RELS =  {
    "REACHING_DEF", "ARG_TO_PARAM", "RET_TO_CALL"
};

using nbr_scan_state_t = std::unique_ptr<graph::NbrScanState>;
using scan_state_map_t = 
    std::unordered_map<table_id_t, std::vector<nbr_scan_state_t>>;

using graph_rel_info_map_t = 
    std::unordered_map<table_id_t, std::vector<graph::GraphRelInfo>>;

/* 
 * Estado de un BFS reanudable desde un source. La misma estructura sirve para 
 * recorrer relaciones FWD o BWD.
*/
struct ReachState {
    internal_id_set_t seen;
    std::deque<nodeID_t> frontier;
};

struct ReachBindData final : public FunctionBindData {
    main::ClientContext* ctx;
    // Se arma una vez en bind, cada copia crea su OnDiskGraph a partir de él.
    graph::NativeGraphEntry graphEntry;
    // Estado propio de cada copia (no se comparten entre evaluadores/hilos) 
    std::unique_ptr<graph::OnDiskGraph> graph;
    // Índices de metadatos: una entrada por coneión entre tablas
    graph_rel_info_map_t fwdRelInfos;
    graph_rel_info_map_t bwdRelInfos;
    // Scan states por tabla y dirección
    scan_state_map_t fwdScanStates;
    scan_state_map_t bwdScanStates;
    // Cache incremental de BFS, indexada por el nodo inicial
    internal_id_map_t<ReachState> fwdReachCache;
    internal_id_map_t<ReachState> bwdReachCache;

    ReachBindData(
        std::vector<LogicalType> params, 
        main::ClientContext* ctx,
        graph::NativeGraphEntry entry
    ):
        FunctionBindData{std::move(params), LogicalType::BOOL()}, 
        ctx{ctx},
        graphEntry{std::move(entry)} {}

    std::unique_ptr<FunctionBindData> copy() const override {
        return std::make_unique<ReachBindData>(
            LogicalType::copy(paramTypes), ctx, graphEntry.copy()
        );
    }

    /*
     * Construye ambos índices recorriendo NativeGraphEntry una sola vez.
     * No se utiliza OnDiskGraph::getRelInfos() porque ese método filtra
     * únicamente por srcTableID. La información de cada conexión está
     * disponible en RelGroupCatalogEntry::getRelEntryInfos().
     */
    void initRelInfoIndexes() {
        if (!fwdRelInfos.empty() || !bwdRelInfos.empty()) {
            return;
        }

        const auto nodeTableIDs = graphEntry.getNodeTableIDs();
        const std::unordered_set<table_id_t> nodeTables{
            nodeTableIDs.begin(), nodeTableIDs.end()
        };

        for (const auto& relInfo : graphEntry.relInfos) {
            auto* relGroup =
                relInfo.entry->ptrCast<catalog::RelGroupCatalogEntry>();

            for (const auto& entryInfo : relGroup->getRelEntryInfos()) {
                const auto srcTableID = entryInfo.nodePair.srcTableID;
                const auto dstTableID = entryInfo.nodePair.dstTableID;

                if (!nodeTables.contains(srcTableID) ||
                    !nodeTables.contains(dstTableID)) {
                    continue;
                }

                graph::GraphRelInfo info{
                    srcTableID,
                    dstTableID,
                    relInfo.entry,
                    entryInfo.oid
                };
                fwdRelInfos[srcTableID].push_back(info);
                bwdRelInfos[dstTableID].push_back(info);
            }
        }
    }

    void initGraph() {
        if (graph == nullptr) {
            graph = std::make_unique<graph::OnDiskGraph>(ctx, graphEntry.copy());
            initRelInfoIndexes();
        }
    }

    // Scan states para cada tabla en la dirección solicitada.
    auto& statesFor(table_id_t tableID, const bool backward) {
        auto& stateCache = backward ? bwdScanStates : fwdScanStates;
        auto& relInfoIndex = backward ? bwdRelInfos : fwdRelInfos;

        auto it = stateCache.find(tableID);
        if (it != stateCache.end()) {
            return it->second;
        }

        auto& states = stateCache[tableID];
        auto relIt = relInfoIndex.find(tableID);
        if (relIt == relInfoIndex.end()) {
            return states;
        }

        states.reserve(relIt->second.size());
        for (const auto& info: relIt->second) {
            // En FWD los vecinos están en dstTableID, en BWD srcTableID
            const auto nbrTableID = 
                backward ? info.srcTableID : info.dstTableID;
            
            auto state = graph->prepareRelScan(
                *info.relGroupEntry,
                info.relTableID,
                nbrTableID,
                std::vector<std::string>{}
            );
            states.push_back(std::move(state));
        }
        return states;
    }

    /*
     * Calcula si un nodo `src` alcanza a otro `dst` por medio de un camino
     * de relaciones de flujo de datos entrantes o salientes. Exapande el BFS 
     * solo hasta encontrar dst, conservando el estado parcial intermedio para 
     * consultas posteriores desde el mismo src
    */
    bool bfs(nodeID_t src, nodeID_t dst, const bool backward = false) {
        auto& cache = backward ? bwdReachCache : fwdReachCache;
        auto [it, inserted] = cache.try_emplace(src);
        auto& state = it->second;
        auto& seen = state.seen;
        auto& frontier = state.frontier;

        if (inserted) {
            seen.insert(src);
            frontier.push_back(src);
        }
        if (seen.contains(dst)) {
            return true;
        }

        initGraph();
        while (!frontier.empty()) {
            auto node = frontier.front();
            frontier.pop_front();

            for (auto& scanState : statesFor(node.tableID, backward)) {
                auto edges = backward 
                    ? graph->scanBwd(node, *scanState)
                    : graph->scanFwd(node, *scanState);

                for (auto chunk : edges) {
                    chunk.forEach([&](auto nbrs, auto /*props*/, auto i) {
                        if (seen.insert(nbrs[i]).second) {
                            frontier.push_back(nbrs[i]);
                        }
                    });
                }
            }
            if (seen.contains(dst)) {
                return true;
            }
        }
        return false;
    }
};

struct ReachOpFwd {
    static void operation(
        internalID_t& src, 
        internalID_t& sink, 
        uint8_t& result, 
        void* dataPtr
    ) {
        auto* bd = static_cast<ReachBindData*>(dataPtr);
        result = bd->bfs(src, sink, false);
    }
};

struct ReachOpBwd {
    static void operation(
        internalID_t& sink, 
        internalID_t& src, 
        uint8_t& result, 
        void* dataPtr
    ) {
        auto* bd = static_cast<ReachBindData*>(dataPtr);
        result = bd->bfs(sink, src, true);
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

static std::unique_ptr<FunctionBindData> bindFunc(
    const ScalarBindFuncInput& input
) {
    auto* ctx = input.context;
    auto catalog = catalog::Catalog::Get(*ctx);
    auto tx = transaction::Transaction::Get(*ctx);

    std::vector<catalog::TableCatalogEntry*> nodes{}, rels{};
    for (auto* entry: catalog->getNodeTableEntries(tx, false)) {
        nodes.push_back(entry);
    }
    for (auto* name : FLOW_RELS) {
        if (catalog->containsTable(tx, name)) {
            rels.push_back(catalog->getTableCatalogEntry(tx, name));
        }
    }
    if (rels.empty()) {
        throw BinderException(
            "reachable_by: no existe ninguna de las tablas "
            "REACHING_DEF, ARG_TO_PARAM, RET_TO_CALL"
        );
    }

    std::vector<LogicalType> params;
    for (auto& arg: input.arguments) {
        params.push_back(arg->getDataType().copy());
    }

    return std::make_unique<ReachBindData>(
        std::move(params), ctx, graph::NativeGraphEntry(nodes, rels)
    );
}


static ValueVector& getIdVector(const std::shared_ptr<ValueVector>& vec) {
    if (vec->dataType.getLogicalTypeID() == LogicalTypeID::NODE) {
        auto idx = StructType::getFieldIdx(vec->dataType, InternalKeyword::ID);
        return *StructVector::getFieldVector(vec.get(), idx);
    }
    return *vec;
}

template<typename OP>
static void execFunc(
    const std::vector<std::shared_ptr<ValueVector>>& params,
    const std::vector<SelectionVector*>& sel, 
    ValueVector& result, 
    SelectionVector* resultSel,
    void* dataPtr
) {
    BinaryFunctionExecutor::executeSwitch
    <internalID_t, internalID_t, uint8_t, OP, ReachWrapper>(
        getIdVector(params[0]), sel[0], 
        getIdVector(params[1]), sel[1], 
        result, resultSel,
        dataPtr
    );
}

template<typename OP>
static bool selectFunc(
    const std::vector<std::shared_ptr<ValueVector>>& params, 
    SelectionVector& selVector,
    void* dataPtr
) {
    auto result = BinaryFunctionExecutor::select
        <internalID_t, internalID_t, OP, ReachWrapper>(
            getIdVector(params[0]), 
            getIdVector(params[1]), 
            selVector, 
            dataPtr
    );
    return result;
}

template<typename OP>
static function_set makeFunctionSet(const std::string& name) {
    function_set set;

    auto func_nodes = std::make_unique<ScalarFunction>(
        name,
        std::vector<LogicalTypeID>{LogicalTypeID::NODE, LogicalTypeID::NODE},
        LogicalTypeID::BOOL, 
        execFunc<OP>, 
        selectFunc<OP>
    );
    func_nodes->bindFunc = bindFunc;
    set.push_back(std::move(func_nodes));

    auto func_ids = std::make_unique<ScalarFunction>(
        name,
        std::vector<LogicalTypeID>{
            LogicalTypeID::INTERNAL_ID, LogicalTypeID::INTERNAL_ID
        },
        LogicalTypeID::BOOL,
        execFunc<OP>,
        selectFunc<OP>
    );
    func_ids->bindFunc = bindFunc;
    set.push_back(std::move(func_ids));

    return set;
}

function_set ReachableByFunction::getFunctionSet() {
    return makeFunctionSet<ReachOpFwd>(name);
}

function_set ReachableByBwdFunction::getFunctionSet() {
    return makeFunctionSet<ReachOpBwd>(name);
}

} // namespace loern_extension
} // namespace lbug