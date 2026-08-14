import importlib.util
import pathlib
import unittest
from unittest.mock import patch


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

    def test_two_step_authentication_uses_a_trusted_device(self):
        device = {"deviceName": "Test iPhone"}

        class Api:
            requires_2fa = False
            requires_2sa = True
            is_trusted_session = False
            trusted_devices = [device]

            def send_verification_code(self, selected):
                self.selected = selected
                return True

            def validate_verification_code(self, selected, code):
                self.code = code
                self.is_trusted_session = True
                return selected is device and code == "123456"

        api = Api()
        with patch("builtins.input", return_value="0"), patch.object(
            APPLE.getpass, "getpass", return_value="123456"
        ):
            self.assertTrue(APPLE.complete_authentication(api))
        self.assertIs(api.selected, device)
        self.assertEqual(api.code, "123456")

    def test_saved_session_must_open_find_my_before_login_succeeds(self):
        class Api:
            requires_2fa = False
            requires_2sa = False
            devices = [object()]

        self.assertTrue(APPLE.find_my_session_usable(Api()))

        class ChallengedApi:
            requires_2fa = True
            requires_2sa = False
            devices = []

        self.assertFalse(APPLE.find_my_session_usable(ChallengedApi()))

    def test_login_stores_password_only_for_a_reusable_find_my_session(self):
        authenticated = type(
            "AuthenticatedApi",
            (),
            {"requires_2fa": False, "requires_2sa": False,
             "is_trusted_session": True},
        )()
        persisted = type(
            "PersistedApi",
            (),
            {"requires_2fa": False, "requires_2sa": False, "devices": [object()]},
        )()

        with patch("builtins.input", return_value="user@example.com"), patch.object(
            APPLE.getpass, "getpass", return_value="secret"
        ), patch.object(APPLE, "service", side_effect=[authenticated, persisted]), patch.object(
            APPLE, "store_password"
        ) as store, patch.object(APPLE, "delete_password") as delete, patch.object(
            APPLE, "write_account"
        ) as write:
            self.assertEqual(APPLE.login(), 0)

        store.assert_called_once_with("user@example.com", "secret")
        delete.assert_not_called()
        write.assert_called_once_with("user@example.com")

    def test_disconnect_removes_the_keyring_password(self):
        with patch.object(APPLE, "read_account", return_value="user@example.com"), patch.object(
            APPLE, "delete_password"
        ) as delete, patch.object(APPLE.shutil, "rmtree"):
            self.assertEqual(APPLE.disconnect(), 0)
        delete.assert_called_once_with("user@example.com")


if __name__ == "__main__":
    unittest.main()
