//! Parser for whitespace-separated joint limit tables:
//!
//! ```text
//! # name      lower   upper  max_velocity
//! fr3_joint1  -2.90   2.90   2.62
//! ```

use std::collections::HashSet;
use std::fs;
use std::path::Path;

#[derive(Debug, Clone, PartialEq)]
pub struct JointLimit {
    pub name: String,
    pub lower: f64,
    pub upper: f64,
    pub max_velocity: f64,
}

pub fn parse(input: &str) -> Vec<JointLimit> {
    let mut out = Vec::new();
    let mut seen = HashSet::new();
    for (i, raw) in input.lines().enumerate() {
        let line = raw.split('#').next().unwrap().trim();
        if line.is_empty() {
            continue;
        }
        let mut fields = line.split_whitespace();
        let name = fields.next().unwrap().to_string();
        let lower: f64 = fields.next().expect("missing lower").parse().unwrap();
        let upper: f64 = fields.next().expect("missing upper").parse().unwrap();
        let max_velocity: f64 = fields.next().expect("missing max_velocity").parse().unwrap();
        if lower >= upper {
            panic!("line {}: lower >= upper", i + 1);
        }
        if !seen.insert(name.clone()) {
            panic!("duplicate joint {name}");
        }
        out.push(JointLimit { name, lower, upper, max_velocity });
    }
    out
}

pub fn parse_file(path: &Path) -> Vec<JointLimit> {
    parse(&fs::read_to_string(path).unwrap())
}
