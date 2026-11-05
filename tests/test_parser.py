#!/usr/bin/env python3
import unittest
import sys
import os
from importlib.machinery import SourceFileLoader

gns3sync_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "bin", "gns3sync"))
gns3sync = SourceFileLoader("gns3sync", gns3sync_path).load_module()

get_web_url_from_git_remote = gns3sync.get_web_url_from_git_remote
sanitize_name = gns3sync.sanitize_name
escape_mermaid = gns3sync.escape_mermaid

class TestGNS3SyncHelpers(unittest.TestCase):

    def test_web_url_conversion(self):
        ssh_url = "git@github.com:hugomossberg/gns3sync.git"
        expected = "https://github.com/hugomossberg/gns3sync"
        self.assertEqual(get_web_url_from_git_remote(ssh_url), expected)

        https_url = "https://github.com/hugomossberg/gns3sync.git"
        self.assertEqual(get_web_url_from_git_remote(https_url), expected)

        gitlab_url = "git@gitlab.com:org/subgroup/project.git"
        self.assertEqual(get_web_url_from_git_remote(gitlab_url), "https://gitlab.com/org/subgroup/project")

    def test_sanitize_name(self):
        self.assertEqual(sanitize_name("Router 1 (Cisco)"), "Router_1_Cisco")
        self.assertEqual(sanitize_name("Övning_Bringup_interoperabilitet"), "Övning_Bringup_interoperabilitet")

    def test_escape_mermaid(self):
        raw = 'Switch2 <--> PC1 ("access")'
        escaped = escape_mermaid(raw)
        self.assertNotIn('"', escaped)
        self.assertNotIn('<', escaped)
        self.assertNotIn('>', escaped)

if __name__ == "__main__":
    unittest.main()
