#include <algorithm>
#include <cctype>
#include <cstdlib>
#include <iostream>
#include <optional>
#include <string>

namespace wolfox_test {

static bool isHex(char value) {
    return std::isxdigit(static_cast<unsigned char>(value)) != 0;
}

static std::optional<std::string> canonicalUUID(std::string value) {
    value.erase(value.begin(), std::find_if(value.begin(), value.end(), [](unsigned char character) {
        return !std::isspace(character);
    }));
    value.erase(std::find_if(value.rbegin(), value.rend(), [](unsigned char character) {
        return !std::isspace(character);
    }).base(), value.end());
    if (value.size() != 36) return std::nullopt;
    for (std::size_t index = 0; index < value.size(); ++index) {
        const bool hyphenPosition = index == 8 || index == 13 || index == 18 || index == 23;
        if (hyphenPosition ? value[index] != '-' : !isHex(value[index])) return std::nullopt;
    }
    std::transform(value.begin(), value.end(), value.begin(), [](unsigned char character) {
        return static_cast<char>(std::toupper(character));
    });
    return value;
}

struct IdentityStore {
    std::optional<std::string> active;

    bool activate(const std::string &value) {
        const auto canonical = canonicalUUID(value);
        if (!canonical) return false;
        active = *canonical;
        return true;
    }

    void deactivate() {
        active.reset();
    }
};

class IdentifierHooks {
public:
    explicit IdentifierHooks(IdentityStore &store) : store_(store) {}

    void setLicenseValid(bool value) {
        licenseValid_ = value;
    }

    std::string idfa(const std::string &original) const {
        const auto unified = activeIdentifier();
        return unified ? *unified : original;
    }

    std::string idfv(const std::string &original) const {
        const auto unified = activeIdentifier();
        return unified ? *unified : original;
    }

    std::optional<std::string> webIdentifierAtDocumentStart() const {
        return activeIdentifier();
    }

private:
    std::optional<std::string> activeIdentifier() const {
        if (!licenseValid_ || !store_.active) return std::nullopt;
        return canonicalUUID(*store_.active);
    }

    IdentityStore &store_;
    bool licenseValid_ = false;
};

class TestSuite {
public:
    void expect(bool condition, const std::string &name) {
        if (condition) {
            ++passed_;
            std::cout << "[PASS] " << name << '\n';
        } else {
            ++failed_;
            std::cerr << "[FAIL] " << name << '\n';
        }
    }

    int finish() const {
        std::cout << "Identifier simulation result: " << passed_ << " passed, "
                  << failed_ << " failed\n";
        return failed_ == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
    }

private:
    int passed_ = 0;
    int failed_ = 0;
};

} // namespace wolfox_test

int main() {
    using namespace wolfox_test;

    constexpr const char *originalIDFA = "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA";
    constexpr const char *originalIDFV = "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB";
    constexpr const char *unifiedLower = "12345678-1234-4abc-8def-1234567890ab";
    constexpr const char *unifiedUpper = "12345678-1234-4ABC-8DEF-1234567890AB";

    TestSuite tests;
    IdentityStore store;
    IdentifierHooks hooks(store);

    tests.expect(hooks.idfa(originalIDFA) == originalIDFA && hooks.idfv(originalIDFV) == originalIDFV,
                 "no active profile returns original IDFA and IDFV");
    tests.expect(!store.activate("not-a-uuid") && !store.active,
                 "invalid UUID is rejected without changing the profile");
    tests.expect(store.activate(std::string("  ") + unifiedLower + "  ") && store.active == unifiedUpper,
                 "valid UUID is trimmed and canonicalized");
    tests.expect(hooks.idfa(originalIDFA) == originalIDFA && hooks.idfv(originalIDFV) == originalIDFV,
                 "invalid runtime license keeps original native identifiers");
    tests.expect(!hooks.webIdentifierAtDocumentStart(),
                 "invalid runtime license does not inject a WebView identifier");

    hooks.setLicenseValid(true);
    tests.expect(hooks.idfa(originalIDFA) == unifiedUpper,
                 "IDFA getter returns the unified identifier synchronously");
    tests.expect(hooks.idfv(originalIDFV) == unifiedUpper,
                 "IDFV getter returns the same unified identifier synchronously");
    tests.expect(hooks.webIdentifierAtDocumentStart() == std::optional<std::string>(unifiedUpper),
                 "WebView document-start identity matches IDFA and IDFV");

    constexpr const char *replacement = "87654321-4321-4ABC-8DEF-BA0987654321";
    tests.expect(store.activate(replacement) && hooks.idfa(originalIDFA) == replacement,
                 "changing the profile affects the next getter call immediately");

    store.deactivate();
    tests.expect(hooks.idfa(originalIDFA) == originalIDFA && hooks.idfv(originalIDFV) == originalIDFV &&
                     !hooks.webIdentifierAtDocumentStart(),
                 "deactivation restores every public identifier path");

    return tests.finish();
}
