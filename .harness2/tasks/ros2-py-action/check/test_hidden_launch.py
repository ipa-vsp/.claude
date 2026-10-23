import os
import unittest

import launch
import launch_testing
import launch_testing.actions
import pytest
import rclpy
from action_msgs.msg import GoalStatus
from ament_index_python.packages import get_package_share_directory
from control_msgs.action import GripperCommand
from launch.launch_description_sources import PythonLaunchDescriptionSource
from rclpy.action import ActionClient


@pytest.mark.launch_test
def generate_test_description():
    path = os.path.join(get_package_share_directory('gripper_action'), 'launch', 'gripper.launch.py')
    return launch.LaunchDescription([
        launch.actions.IncludeLaunchDescription(PythonLaunchDescriptionSource(path)),
        launch_testing.actions.ReadyToTest(),
    ])


class TestGripperAction(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        rclpy.init()
        cls.node = rclpy.create_node('gripper_acceptance_client')
        cls.client = ActionClient(cls.node, GripperCommand, '/gripper/gripper_cmd')
        assert cls.client.wait_for_server(timeout_sec=20.0), 'action server not available'

    @classmethod
    def tearDownClass(cls):
        cls.client.destroy()
        cls.node.destroy_node()
        rclpy.shutdown()

    def _wait(self, future, timeout=20.0):
        rclpy.spin_until_future_complete(self.node, future, timeout_sec=timeout)
        self.assertTrue(future.done(), 'timed out')
        return future.result()

    def _goal(self, position, effort=10.0):
        g = GripperCommand.Goal()
        g.command.position = position
        g.command.max_effort = effort
        return g

    def test_1_reaches_goal_with_feedback(self):
        feedback = []
        handle = self._wait(self.client.send_goal_async(
            self._goal(0.05), feedback_callback=lambda fb: feedback.append(fb.feedback)))
        self.assertTrue(handle.accepted)
        res = self._wait(handle.get_result_async())
        self.assertEqual(res.status, GoalStatus.STATUS_SUCCEEDED)
        self.assertTrue(res.result.reached_goal)
        self.assertFalse(res.result.stalled)
        self.assertAlmostEqual(res.result.position, 0.05, delta=1e-3)
        self.assertGreaterEqual(len(feedback), 2)

    def test_2_rejects_out_of_range(self):
        for bad in (0.2, -0.01):
            handle = self._wait(self.client.send_goal_async(self._goal(bad)))
            self.assertFalse(handle.accepted, f'goal {bad} should be rejected')

    def test_3_cancel(self):
        got_feedback = rclpy.task.Future()

        def on_fb(_):
            if not got_feedback.done():
                got_feedback.set_result(True)
        handle = self._wait(self.client.send_goal_async(self._goal(0.0), feedback_callback=on_fb))
        self.assertTrue(handle.accepted)
        self._wait(got_feedback)
        cancel = self._wait(handle.cancel_goal_async())
        self.assertGreaterEqual(len(cancel.goals_canceling), 1)
        res = self._wait(handle.get_result_async())
        self.assertEqual(res.status, GoalStatus.STATUS_CANCELED)
