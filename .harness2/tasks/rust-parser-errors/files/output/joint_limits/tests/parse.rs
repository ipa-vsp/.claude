use joint_limits::parse;

#[test]
fn parses_fr3_table() {
    let limits = parse(include_str!("../data/fr3.limits"));
    assert_eq!(limits.len(), 3);
    assert_eq!(limits[1].name, "fr3_joint2");
}
