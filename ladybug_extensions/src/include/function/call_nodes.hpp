// src/include/function/call_nodes.hpp
#pragma once

#include "extension/extension.h"

namespace lbug {
namespace loern_extension {

struct IsArithmeticFunction {
    static constexpr const char* name = "is_arithmetic";
    static function::function_set getFunctionSet();
};

} // namespace loern_extension
} // namespace lbug