import importlib.util
import pathlib
import unittest


SOURCE = pathlib.Path(__file__).parents[1] / "dots/.config/quickshell/ii/scripts/apple/battery-status.py"
SPEC = importlib.util.spec_from_file_location("apple_battery_status", SOURCE)
APPLE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(APPLE)


class AppleBatteryStatusTests(unittest.TestCase):
    def test_stable_id_hides_raw_find_my_identifier(self):
        value = APPLE.stable_id("raw-device-id")
        self.assertRegex(value, r"^icloud:[0-9a-f]{16}$")
        self.assertNotIn("raw-device-id", value)

    def test_normalize_level_accepts_only_unit_interval(self):
        self.assertEqual(APPLE.normalize_level(0.63), 0.63)
        self.assertIsNone(APPLE.normalize_level(-0.1))
        self.assertIsNone(APPLE.normalize_level(1.1))
        self.assertIsNone(APPLE.normalize_level(True))

    def test_charging_state_keeps_known_separate_from_value(self):
        self.assertEqual(APPLE.normalize_charging("Charging"), (True, True))
        self.assertEqual(APPLE.normalize_charging("NotCharging"), (False, True))
        self.assertEqual(APPLE.normalize_charging("Unknown"), (False, False))

    def test_unknown_battery_status_requires_online_device_status(self):
        self.assertTrue(APPLE.battery_reliable("Unknown", "200"))
        self.assertFalse(APPLE.battery_reliable("Unknown", "203"))
        self.assertTrue(APPLE.battery_reliable("NotCharging", "203"))


if __name__ == "__main__":
    unittest.main()
