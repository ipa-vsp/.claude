from planar_arm import forward


def test_forward_zero():
    assert forward(0.0, 0.0, 1.0, 1.0) == (2.0, 0.0)
