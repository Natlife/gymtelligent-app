"""
Reference repetition-counting logic for the Gymtelligent mobile handover.

The TFLite model predicts an exercise label:
barbell biceps curl, push-up, shoulder press, squat

It does not predict UP/DOWN states. Counting is done with MediaPipe landmark
angles, matching the Python project thresholds.
"""

from dataclasses import dataclass, field
import math


def angle(a, b, c):
    """Return the 2D angle ABC in degrees, matching PoseModule2.find_angle."""
    radians = math.atan2(c[1] - b[1], c[0] - b[0]) - math.atan2(a[1] - b[1], a[0] - b[0])
    degrees = math.degrees(radians)
    if degrees < 0:
        degrees += 360
    return degrees


@dataclass
class CounterState:
    counters: dict = field(default_factory=lambda: {
        "push_up": 0,
        "squat": 0,
        "bicep_curl": 0,
        "shoulder_press": 0,
    })
    stages: dict = field(default_factory=lambda: {
        "push_up": None,
        "squat": None,
        "right_bicep_curl": None,
        "left_bicep_curl": None,
        "shoulder_press": None,
    })


def update_counter(predicted_label, landmark_xy, state):
    """
    predicted_label: one of the model labels.
    landmark_xy: dict[int, tuple[float, float]] using MediaPipe landmark ids.
    state: CounterState, kept across frames.
    """
    if predicted_label == "push-up":
        left_arm = angle(landmark_xy[11], landmark_xy[13], landmark_xy[15])
        if left_arm < 220:
            state.stages["push_up"] = "down"
        if left_arm > 240 and state.stages["push_up"] == "down":
            state.stages["push_up"] = "up"
            state.counters["push_up"] += 1

    elif predicted_label == "squat":
        right_leg = angle(landmark_xy[24], landmark_xy[26], landmark_xy[28])
        left_leg = angle(landmark_xy[23], landmark_xy[25], landmark_xy[27])
        if right_leg > 160 and left_leg < 220:
            state.stages["squat"] = "down"
        if right_leg < 140 and left_leg > 210 and state.stages["squat"] == "down":
            state.stages["squat"] = "up"
            state.counters["squat"] += 1

    elif predicted_label == "barbell biceps curl":
        right_arm = angle(landmark_xy[12], landmark_xy[14], landmark_xy[16])
        left_arm = angle(landmark_xy[11], landmark_xy[13], landmark_xy[15])
        if 160 < right_arm < 200:
            state.stages["right_bicep_curl"] = "down"
        if 140 < left_arm < 200:
            state.stages["left_bicep_curl"] = "down"
        right_top = right_arm > 310 or right_arm < 60
        left_top = left_arm > 310 or left_arm < 60
        if (
            state.stages["right_bicep_curl"] == "down"
            and state.stages["left_bicep_curl"] == "down"
            and right_top
            and left_top
        ):
            state.stages["right_bicep_curl"] = "up"
            state.stages["left_bicep_curl"] = "up"
            state.counters["bicep_curl"] += 1

    elif predicted_label == "shoulder press":
        right_arm = angle(landmark_xy[12], landmark_xy[14], landmark_xy[16])
        left_arm = angle(landmark_xy[11], landmark_xy[13], landmark_xy[15])
        if right_arm > 280 and left_arm < 80:
            state.stages["shoulder_press"] = "down"
        if right_arm < 240 and left_arm > 120 and state.stages["shoulder_press"] == "down":
            state.stages["shoulder_press"] = "up"
            state.counters["shoulder_press"] += 1

    return state
