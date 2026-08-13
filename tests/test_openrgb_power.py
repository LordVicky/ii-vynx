import importlib.util
import pathlib
import unittest


SOURCE = pathlib.Path(__file__).parents[1] / "dots/.config/quickshell/ii/services/OpenRgbPower.py"
SPEC = importlib.util.spec_from_file_location("openrgb_power", SOURCE)
POWER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(POWER)


DEVICE_LIST = """0: ASUS PRIME X670-P WIFI
  Type: Mainboard
  Description: ASUS Aura USB Mainboard Device
  Location: HID: /dev/hidraw10
  Serial: 9876543210
1: wled
  Type: E1.31
  Description: E1.31 Streaming ACN Device
  Location: E1.31: Unicast 192.168.0.105, Universe 1
  Serial:
2: wled
  Type: E1.31
  Description: E1.31 Streaming ACN Device
  Location: E1.31: Unicast 192.168.0.104, Universe 1
  Serial:
"""


class OpenRgbPowerTests(unittest.TestCase):
    def setUp(self):
        self.devices = POWER.parse_devices(DEVICE_LIST)

    def test_parses_live_device_identity_fields(self):
        self.assertEqual(self.devices[1], {
            "index": 1,
            "name": "wled",
            "description": "E1.31 Streaming ACN Device",
            "location": "E1.31: Unicast 192.168.0.105, Universe 1",
            "serial": "",
        })

    def test_wled_uses_exact_e131_location(self):
        assignments = [{
            "name": "wled",
            "description": "E1.31 Streaming ACN Device",
            "location": "E1.31: Unicast 192.168.0.105, Universe 1",
            "serial": "",
        }]
        self.assertEqual(POWER.match_effect_devices(assignments, self.devices), [1])

    def test_hid_device_falls_back_to_serial_when_location_changes(self):
        assignments = [{
            "name": "ASUS PRIME X670-P WIFI",
            "description": "ASUS Aura USB Mainboard Device",
            "location": "HID: /dev/hidraw7",
            "serial": "9876543210",
        }]
        self.assertEqual(POWER.match_effect_devices(assignments, self.devices), [0])

    def test_duplicate_zones_produce_one_device_index(self):
        assignment = {
            "name": "ASUS PRIME X670-P WIFI",
            "description": "ASUS Aura USB Mainboard Device",
            "location": "HID: /dev/hidraw10",
            "serial": "9876543210",
        }
        self.assertEqual(POWER.match_effect_devices([assignment, assignment], self.devices), [0])

    def test_orp_prefers_embedded_location_to_ambiguous_name(self):
        profile = b"OPENRGB_PROFILE\x00wled\x00E1.31: Unicast 192.168.0.105, Universe 1\x00"
        self.assertEqual(POWER.match_orp_devices(profile, self.devices), [1])

    def test_targeted_color_command_rejects_empty_scope(self):
        with self.assertRaisesRegex(ValueError, "No assigned devices matched"):
            POWER.color_command("openrgb", [])

    def test_targeted_color_command_addresses_each_resolved_index(self):
        self.assertEqual(POWER.color_command("openrgb", [0, 2]), [
            "openrgb", "--device", "0", "--color", "000000",
            "--device", "2", "--color", "000000",
        ])


if __name__ == "__main__":
    unittest.main()
