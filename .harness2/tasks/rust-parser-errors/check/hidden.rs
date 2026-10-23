use joint_limits::{parse, parse_file, ParseError};
use std::error::Error;

fn assert_traits<T: Error + Send + Sync + 'static>() {}

#[test]
fn error_traits() {
    assert_traits::<ParseError>();
}

#[test]
fn ok_with_comments_and_blank_lines() {
    let v = parse("\n# c\n j1 -1 1 2 # tail\n\nj2 -2 2.5 1e-1\n").expect("valid");
    assert_eq!(v.len(), 2);
    assert_eq!(v[1].name, "j2");
    assert!((v[1].max_velocity - 0.1).abs() < 1e-12);
}

#[test]
fn missing_fields() {
    assert!(matches!(parse("j1 -1 1\n"), Err(ParseError::MissingField { line: 1, field: "max_velocity" })));
    assert!(matches!(parse("\nj1\n"), Err(ParseError::MissingField { line: 2, field: "lower" })));
    assert!(matches!(parse("j1 -1\n"), Err(ParseError::MissingField { line: 1, field: "upper" })));
}

#[test]
fn invalid_number() {
    match parse("j1 -1 abc 2\n") {
        Err(ParseError::InvalidNumber { line: 1, field: "upper", value }) => assert_eq!(value, "abc"),
        other => panic!("unexpected {other:?}"),
    }
}

#[test]
fn inverted_and_velocity() {
    assert!(matches!(parse("j1 1 1 2\n"), Err(ParseError::InvertedLimits { line: 1 })));
    assert!(matches!(parse("j1 -1 1 0\n"), Err(ParseError::NonPositiveVelocity { line: 1 })));
}

#[test]
fn duplicate_and_trailing() {
    match parse("a -1 1 1\nb -1 1 1\na -1 1 1\n") {
        Err(ParseError::DuplicateJoint { line: 3, name }) => assert_eq!(name, "a"),
        other => panic!("unexpected {other:?}"),
    }
    assert!(matches!(parse("a -1 1 1 9\n"), Err(ParseError::TrailingFields { line: 1 })));
}

#[test]
fn io_error_has_source() {
    let err = parse_file("/definitely/not/here.limits").unwrap_err();
    assert!(matches!(err, ParseError::Io(_)));
    assert!(err.source().is_some());
    assert!(!err.to_string().is_empty());
}

#[test]
fn parse_file_accepts_str_and_pathbuf() {
    let p = std::path::PathBuf::from(concat!(env!("CARGO_MANIFEST_DIR"), "/data/fr3.limits"));
    assert_eq!(parse_file(&p).expect("fr3").len(), 3);
    assert_eq!(parse_file(p.to_str().expect("utf8")).expect("fr3").len(), 3);
}
