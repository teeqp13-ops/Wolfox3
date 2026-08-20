#include <cmath>
#include <cstdlib>
#include <iostream>
#include <optional>
#include <string>
#include <vector>

namespace wolfox_test {

struct Coordinate {
    double latitude = 0.0;
    double longitude = 0.0;
};

static bool validCoordinate(const Coordinate &coordinate) {
    return std::isfinite(coordinate.latitude) &&
           std::isfinite(coordinate.longitude) &&
           coordinate.latitude >= -90.0 && coordinate.latitude <= 90.0 &&
           coordinate.longitude >= -180.0 && coordinate.longitude <= 180.0;
}

static bool sameCoordinate(const Coordinate &left, const Coordinate &right, double epsilon = 1e-9) {
    return std::fabs(left.latitude - right.latitude) <= epsilon &&
           std::fabs(left.longitude - right.longitude) <= epsilon;
}

struct Location {
    Coordinate coordinate;
    bool wolfoxSynthetic = false;
};

struct Store {
    bool spoofActive = false;
    bool licenseValid = false;
    Coordinate fake{24.7136, 46.6753};
};

struct RecordingDelegate {
    std::vector<Location> updates;

    void didUpdate(const Location &location) {
        updates.push_back(location);
    }
};

struct Manager {
    Location real;
    RecordingDelegate *delegate = nullptr;
};

class LocationHookRuntime {
public:
    explicit LocationHookRuntime(Store &store) : store_(store) {}

    void attach(Manager &manager) {
        managers_.push_back(&manager);
    }

    Location managerLocation(const Manager &manager) const {
        if (gate()) return Location{store_.fake, true};
        return manager.real;
    }

    Coordinate locationCoordinate(const Location &location) const {
        if (location.wolfoxSynthetic) return location.coordinate;
        if (gate()) return store_.fake;
        return location.coordinate;
    }

    void receiveRealUpdate(Manager &manager, const Location &real) const {
        manager.real = real;
        if (!manager.delegate) return;
        manager.delegate->didUpdate(gate() ? Location{store_.fake, true} : real);
    }

    std::size_t deliverFakeUpdate() const {
        if (!gate()) return 0;
        std::size_t delivered = 0;
        for (Manager *manager : managers_) {
            if (!manager || !manager->delegate) continue;
            manager->delegate->didUpdate(Location{store_.fake, true});
            ++delivered;
        }
        return delivered;
    }

    std::size_t licenseStateChanged(bool valid) {
        store_.licenseValid = valid;
        if (valid && store_.spoofActive) return deliverFakeUpdate();
        return 0;
    }

private:
    bool gate() const {
        return store_.spoofActive && store_.licenseValid && validCoordinate(store_.fake);
    }

    Store &store_;
    std::vector<Manager *> managers_;
};

static Coordinate loadSavedCoordinate(std::optional<double> latitude,
                                       std::optional<double> longitude) {
    const Coordinate fallback{24.7136, 46.6753};
    if (!latitude || !longitude) return fallback;
    const Coordinate saved{*latitude, *longitude};
    return validCoordinate(saved) ? saved : fallback;
}

static Coordinate routeStep(Coordinate current, Coordinate target, double speedKmh) {
    const double speedKmPerSecond = speedKmh / 3600.0;
    const double stepDegrees = speedKmPerSecond / 111.1;
    const double latitudeDelta = target.latitude - current.latitude;
    const double longitudeDelta = target.longitude - current.longitude;
    const double distance = std::sqrt(latitudeDelta * latitudeDelta + longitudeDelta * longitudeDelta);
    if (distance <= stepDegrees || distance < 1e-9) return target;
    current.latitude += (latitudeDelta / distance) * stepDegrees;
    current.longitude += (longitudeDelta / distance) * stepDegrees;
    return current;
}

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
        std::cout << "Linux simulation result: " << passed_ << " passed, "
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

    TestSuite tests;
    Store store;
    LocationHookRuntime runtime(store);
    RecordingDelegate firstDelegate;
    RecordingDelegate secondDelegate;
    Manager first{{{21.5433, 39.1728}, false}, &firstDelegate};
    Manager second{{{25.2854, 51.5310}, false}, &secondDelegate};
    runtime.attach(first);
    runtime.attach(second);

    tests.expect(sameCoordinate(runtime.managerLocation(first).coordinate, first.real.coordinate),
                 "inactive manager.location returns the real coordinate");

    store.spoofActive = true;
    tests.expect(sameCoordinate(runtime.managerLocation(first).coordinate, first.real.coordinate),
                 "invalid runtime license keeps the real coordinate");

    store.licenseValid = true;
    tests.expect(sameCoordinate(runtime.managerLocation(first).coordinate, store.fake),
                 "active manager.location returns the fake coordinate immediately");
    tests.expect(runtime.managerLocation(first).wolfoxSynthetic,
                 "synthetic manager.location result carries the WolFox marker");

    Location unmarkedReal{{40.7128, -74.0060}, false};
    tests.expect(sameCoordinate(runtime.locationCoordinate(unmarkedReal), store.fake),
                 "CLLocation.coordinate hook replaces an unmarked real object");

    Location markedInternal{{35.6895, 139.6917}, true};
    tests.expect(sameCoordinate(runtime.locationCoordinate(markedInternal), markedInternal.coordinate),
                 "WolFox marker prevents double spoofing");

    runtime.receiveRealUpdate(first, Location{{48.8566, 2.3522}, false});
    tests.expect(firstDelegate.updates.size() == 1 &&
                     sameCoordinate(firstDelegate.updates.back().coordinate, store.fake),
                 "delegate proxy replaces a real callback synchronously");

    const std::size_t beforeFirst = firstDelegate.updates.size();
    const std::size_t beforeSecond = secondDelegate.updates.size();
    const std::size_t delivered = runtime.deliverFakeUpdate();
    tests.expect(delivered == 2 && firstDelegate.updates.size() == beforeFirst + 1 &&
                     secondDelegate.updates.size() == beforeSecond + 1,
                 "deliverFakeUpdate reaches every attached delegate before returning");

    store.licenseValid = false;
    const std::size_t beforeLicenseReady = firstDelegate.updates.size();
    const std::size_t licenseDeliveries = runtime.licenseStateChanged(true);
    tests.expect(licenseDeliveries == 2 && firstDelegate.updates.size() == beforeLicenseReady + 1,
                 "successful license validation sends an immediate fake update");

    store.fake = {91.0, 46.0};
    tests.expect(runtime.deliverFakeUpdate() == 0 &&
                     sameCoordinate(runtime.managerLocation(first).coordinate, first.real.coordinate),
                 "out-of-range fake coordinates safely fall back to the real location");

    tests.expect(validCoordinate({0.0, 0.0}) && validCoordinate({-90.0, -180.0}) &&
                     validCoordinate({90.0, 180.0}),
                 "zero, equator, Greenwich and boundary coordinates are accepted");
    tests.expect(!validCoordinate({-90.0001, 0.0}) && !validCoordinate({0.0, 180.0001}) &&
                     !validCoordinate({NAN, 1.0}),
                 "invalid and non-finite coordinates are rejected");

    const Coordinate restoredZero = loadSavedCoordinate(0.0, 0.0);
    const Coordinate restoredFallback = loadSavedCoordinate(999.0, 999.0);
    tests.expect(sameCoordinate(restoredZero, {0.0, 0.0}),
                 "persistence restores a valid zero coordinate without replacing it");
    tests.expect(sameCoordinate(restoredFallback, {24.7136, 46.6753}),
                 "persistence replaces corrupted coordinates with the safe default");

    const Coordinate stepped = routeStep({24.0, 46.0}, {25.0, 46.0}, 5.0);
    const double routeMeters = (stepped.latitude - 24.0) * 111100.0;
    tests.expect(std::fabs(routeMeters - 1.388888) < 0.02,
                 "5 km/h route simulation advances about 1.39 meters per second");

    return tests.finish();
}
