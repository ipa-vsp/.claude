import tomllib


def load_config(path):
    with open(path, "rb") as f:
        data = tomllib.load(f)
    cfg = {}
    cfg["name"] = data["name"]
    cfg["update_rate_hz"] = data.get("update_rate_hz", 100)
    cfg["joints"] = []
    for j in data["joints"]:
        cfg["joints"].append({
            "name": j["name"],
            "min_position": j["min_position"],
            "max_position": j["max_position"],
            "max_velocity": j["max_velocity"],
        })
    c = data["controller"]
    cfg["controller"] = {"type": c["type"], "gains": c.get("gains", {})}
    return cfg


def joint_names(cfg):
    return [j["name"] for j in cfg["joints"]]
