#pragma once

#include "extension/extension.h"

namespace lbug {
namespace loern_extension {

struct ReachableByFunction {
    static constexpr const char* name = "reachable_by";
    static function::function_set getFunctionSet();
};

} // namespace loern_extension
} // namespace lbug