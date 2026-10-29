#include "loern_call_node.hpp"

#include "common/api.h"
#include "common/exception/binder.h"
#include "common/types/string_t.h"
#include "common/vector/value_vector.h"
#include "extension/extension.h"
#include "function/scalar_function.h"
#include "function/unary_function_executor.h"
#include "main/client_context.h"
#include "main/database.h"

using namespace lbug::common;
using namespace lbug::function;

namespace lbug {
namespace loern_call_node {

static constexpr const char* PROPERTY = "NAME";

// Lógica pura sobre el valor de la propiedad NAME.
struct IsArithmeticOp {
    static void operation(string_t& input, bool& result) {
        const auto s = input.getAsString();
        result = s == "<operator>.addition" ||
                 s == "<operator>.subtraction" ||
                 s == "<operator>.multiplication" ||
                 s == "<operator>.division";
    }
};

// Valida en tiempo de bind que el nodo tenga la propiedad NAME.
static std::unique_ptr<FunctionBindData> bindFunc(
    const ScalarBindFuncInput& input
) {
    const auto& nodeType = input.arguments[0]->getDataType();
    auto idx = StructType::getFieldIdx(nodeType, PROPERTY);
    if (idx == INVALID_STRUCT_FIELD_IDX) {
        throw BinderException(
            std::string("is_arithmetic() requires a node with property ") + 
            PROPERTY
        );
    }
    std::vector<LogicalType> paramTypes;
    paramTypes.push_back(nodeType.copy());
    return std::make_unique<FunctionBindData>(
        std::move(paramTypes), 
        LogicalType::BOOL()
    );
}

// Un nodo en el motor es un vector STRUCT: sacamos el campo NAME y le aplicamos Op.
// Es lo mismo que hace n.NAME (struct_extract), más el predicado.
static void execFunc(
    const std::vector<std::shared_ptr<ValueVector>>& params,
    const std::vector<SelectionVector*>& paramSelVectors, 
    ValueVector& result,
    SelectionVector* resultSelVector, 
    void* /*dataPtr*/
) {
    auto idx = StructType::getFieldIdx(params[0]->dataType, PROPERTY);
    auto nameVector = StructVector::getFieldVector(params[0].get(), idx);
    UnaryFunctionExecutor::execute<string_t, bool, IsArithmeticOp>(
        *nameVector,
        paramSelVectors[0],
        result, 
        resultSelVector
    );
}

struct IsArithmeticFunction {
    static constexpr const char* name = "is_arithmetic";

    static function_set getFunctionSet() {
        function_set set;
        auto func = std::make_unique<ScalarFunction>(
            name,
            std::vector<LogicalTypeID>{LogicalTypeID::NODE}, 
            LogicalTypeID::BOOL, 
            execFunc
        );
        func->bindFunc = bindFunc;
        set.push_back(std::move(func));
        return set;
    }
};

void LoernCallNode::load(main::ClientContext* context) {
    auto& db = *context->getDatabase();
    extension::ExtensionUtils::addScalarFunc<IsArithmeticFunction>(db);
}

} // namespace arithmetic_extension
} // namespace lbug

extern "C" {

LBUG_API void init(lbug::main::ClientContext* context) {
    lbug::loern_call_node::LoernCallNode::load(context);
}

LBUG_API const char* name() {
    return lbug::loern_call_node::LoernCallNode::EXTENSION_NAME;
}

}