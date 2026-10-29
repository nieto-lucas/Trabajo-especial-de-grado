// src/include/loern_call_node.hpp
#pragma once

#include "extension/extension.h"

namespace lbug {

namespace main { class ClientContext; }

namespace loern_call_node {

class LoernCallNode final : public extension::Extension {
public:
    static constexpr char EXTENSION_NAME[] = "LOERN_CALL_NODE";
    static void load(main::ClientContext* context);
};

} // namespace loern_call_node
} // namespace lbug