#if canImport(Combine)
import Foundation
import Combine

/// A convenience type to specify a `TestScheduler` by the scheduler it wraps rather than by the
/// time type and options type.
public typealias TestSchedulerOf<Scheduler> = TestScheduler<Scheduler.SchedulerTimeType, Scheduler.SchedulerOptions> where Scheduler: Combine.Scheduler

extension Scheduler where
    SchedulerTimeType == DispatchQueue.SchedulerTimeType,
    SchedulerOptions == DispatchQueue.SchedulerOptions
{
    /// A test scheduler of dispatch queues.
    @inlinable public static var testScheduler: TestSchedulerOf<Self> {
        // NB: `DispatchTime(uptimeNanoseconds: 0) == .now())`. Use `1` for consistency.
        TestScheduler(now: SchedulerTimeType(DispatchTime(uptimeNanoseconds: 1)))
    }
}

extension Scheduler where
    SchedulerTimeType == RunLoop.SchedulerTimeType,
    SchedulerOptions == RunLoop.SchedulerOptions
{
    /// A test scheduler of run loops.
    @inlinable public static var testScheduler: TestSchedulerOf<Self> {
        TestScheduler(now: SchedulerTimeType(Date(timeIntervalSince1970: 0)))
    }
}

extension Scheduler where
    SchedulerTimeType == OperationQueue.SchedulerTimeType,
    SchedulerOptions == OperationQueue.SchedulerOptions
{
    /// A test scheduler of operation queues.
    @inlinable public static var testScheduler: TestSchedulerOf<Self> {
        TestScheduler(now: SchedulerTimeType(Date(timeIntervalSince1970: 0)))
    }
}

public final class TestScheduler<SchedulerTimeType, SchedulerOptions> where
    SchedulerTimeType: Strideable,
    SchedulerTimeType.Stride: SchedulerTimeIntervalConvertible
{
    private var lastSequence: UInt = 0
    public let minimumTolerance: SchedulerTimeType.Stride = .zero
    public private(set) var now: SchedulerTimeType
    private var scheduled: [(sequence: UInt, date: SchedulerTimeType, action: () -> Void)] = []
    
    /// Creates a test scheduler with the given date.
    ///
    /// - Parameter now: The current date of the test scheduler.
    public init(now: SchedulerTimeType) {
        self.now = now
    }
}

extension TestScheduler: Scheduler {
    
    /// Advances the scheduler by the given stride.
    ///
    /// - Parameter stride: A stride. By default this argument is `.zero`, which does not advance the
    ///   scheduler's time but does cause the scheduler to execute any units of work that are waiting
    ///   to be performed for right now.
    public func advance(by stride: SchedulerTimeType.Stride = .zero) {
        
        let finalDate = self.now.advanced(by: stride)
        
        while self.now <= finalDate {
            self.scheduled.sort { ($0.date, $0.sequence) < ($1.date, $1.sequence) }
            
            guard
                let nextDate = self.scheduled.first?.date,
                finalDate >= nextDate
            else {
                self.now = finalDate
                return
            }
            
            self.now = nextDate
            
            while let (_, date, action) = self.scheduled.first, date == nextDate {
                self.scheduled.removeFirst()
                action()
            }
        }
    }
    
    /// Runs the scheduler until it has no scheduled items left.
    ///
    /// This method is useful for proving exhaustively that your publisher eventually completes
    /// and does not run forever. For example, the following code will run an infinite loop forever
    /// because the timer never finishes:
    ///
    ///     let scheduler = DispatchQueue.testScheduler
    ///     Publishers.Timer(every: .seconds(1), scheduler: scheduler)
    ///       .sink { _ in print($0) }
    ///       .store(in: &cancellables)
    ///
    ///     scheduler.run() // Will never complete
    ///
    /// If you wanted to make sure that this publisher eventually completes you would need to
    /// chain on another operator that completes it when a certain condition is met. This can be
    /// done in many ways, such as using `prefix`:
    ///
    ///     let scheduler = DispatchQueue.testScheduler
    ///     Publishers.Timer(every: .seconds(1), scheduler: scheduler)
    ///       .prefix(3)
    ///       .sink { _ in print($0) }
    ///       .store(in: &cancellables)
    ///
    ///     scheduler.run() // Prints 3 times and completes.
    ///
    public func run() {
        while let date = self.scheduled.first?.date {
            self.advance(by: self.now.distance(to: date))
        }
    }
    
    public func schedule(
        after date: SchedulerTimeType,
        interval: SchedulerTimeType.Stride,
        tolerance _: SchedulerTimeType.Stride,
        options _: SchedulerOptions?,
        _ action: @escaping () -> Void
    ) -> Cancellable {
        let sequence = self.nextSequence()
        
        func scheduleAction(for date: SchedulerTimeType) -> () -> Void {
            return { [weak self] in
                let nextDate = date.advanced(by: interval)
                self?.scheduled.append((sequence, nextDate, scheduleAction(for: nextDate)))
                action()
            }
        }
        
        self.scheduled.append((sequence, date, scheduleAction(for: date)))
        
        return AnyCancellable { [weak self] in
            self?.scheduled.removeAll(where: { $0.sequence == sequence })
        }
    }
    
    public func schedule(
        after date: SchedulerTimeType,
        tolerance _: SchedulerTimeType.Stride,
        options _: SchedulerOptions?,
        _ action: @escaping () -> Void
    ) {
        self.scheduled.append((self.nextSequence(), date, action))
    }
    
    public func schedule(options _: SchedulerOptions?, _ action: @escaping () -> Void) {
        self.scheduled.append((self.nextSequence(), self.now, action))
    }
    
    private func nextSequence() -> UInt {
        self.lastSequence += 1
        return self.lastSequence
    }
}
#endif
