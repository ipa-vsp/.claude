use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{mpsc, Arc, Barrier};
use std::time::Duration;
use worker_pool::{PoolError, ThreadPool};

fn assert_err<T: std::error::Error + Send + Sync + 'static>() {}

#[test]
fn zero_workers() {
    assert_err::<PoolError>();
    assert!(matches!(ThreadPool::new(0), Err(PoolError::ZeroWorkers)));
    assert_eq!(ThreadPool::new(3).expect("pool").workers(), 3);
}

#[test]
fn drop_drains_queue() {
    let n = Arc::new(AtomicUsize::new(0));
    {
        let pool = ThreadPool::new(4).expect("pool");
        for _ in 0..2000 {
            let n = Arc::clone(&n);
            pool.execute(move || { n.fetch_add(1, Ordering::SeqCst); }).expect("execute");
        }
    }
    assert_eq!(n.load(Ordering::SeqCst), 2000);
}

#[test]
fn shutdown_drains_queue() {
    let n = Arc::new(AtomicUsize::new(0));
    let pool = ThreadPool::new(2).expect("pool");
    for _ in 0..500 {
        let n = Arc::clone(&n);
        pool.execute(move || { n.fetch_add(1, Ordering::SeqCst); }).expect("execute");
    }
    pool.shutdown();
    assert_eq!(n.load(Ordering::SeqCst), 500);
}

#[test]
fn survives_panics_single_worker() {
    let pool = ThreadPool::new(1).expect("pool");
    for _ in 0..3 {
        pool.execute(|| panic!("boom (expected by test)")).expect("execute");
    }
    let (tx, rx) = mpsc::channel();
    pool.execute(move || tx.send(7).expect("send")).expect("execute");
    assert_eq!(rx.recv_timeout(Duration::from_secs(10)).expect("job after panic ran"), 7);
    assert_eq!(pool.workers(), 1);
}

#[test]
fn runs_in_parallel() {
    let workers = 4;
    let pool = ThreadPool::new(workers).expect("pool");
    let barrier = Arc::new(Barrier::new(workers + 1));
    for _ in 0..workers {
        let b = Arc::clone(&barrier);
        pool.execute(move || { b.wait(); }).expect("execute");
    }
    let (tx, rx) = mpsc::channel();
    std::thread::spawn(move || { barrier.wait(); tx.send(()).ok(); });
    rx.recv_timeout(Duration::from_secs(10)).expect("all workers ran concurrently");
}
