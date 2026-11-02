#include "main/loern_extension.hpp"
#include "function/call_nodes.hpp"

#include "main/client_context.h"

namespace lbug {
namespace loern_extension {

using namespace extension;

void LoernExtension::load(main::ClientContext* context) {
    auto& db = *context->getDatabase();
    ExtensionUtils::addScalarFunc<IsArithmeticFunction>(db);
}

} // namespace loern_extension
} // namespace lbug

extern "C" {

LBUG_API void init(lbug::main::ClientContext* context) {
    lbug::loern_extension::LoernExtension::load(context);
}

LBUG_API const char* name() {
    return lbug::loern_extension::LoernExtension::EXTENSION_NAME;
}

}