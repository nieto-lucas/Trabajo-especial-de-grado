#pragma once

#include "extension/extension.h"

namespace lbug {
namespace loern_extension {

class LoernExtension final : public extension::Extension {
public:
    static constexpr char EXTENSION_NAME[] = "LOERN";
    static void load(main::ClientContext* context);
};

} // namespace loern_extension
} // namespace lbug