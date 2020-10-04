#if canImport(Combine)
import Combine

/// A convenience type to specify an `AnyScheduler` by the scheduler it wraps rather than by the
/// time type and options type.
public typealias AnySchedulerOf<Scheduler> = AnyScheduler<Scheduler.SchedulerTimeType, Scheduler.SchedulerOptions> where Scheduler: Combine.Scheduler

extension Scheduler {
    
    /// Wraps this scheduler with a type eraser.
    @inlinable public func eraseToAnyScheduler() -> AnyScheduler<SchedulerTimeType, SchedulerOptions> {
        AnyScheduler(self)
    }
}

public struct AnyScheduler<SchedulerTimeType, SchedulerOptions> where
    SchedulerTimeType: Strideable,
    SchedulerTimeType.Stride: SchedulerTimeIntervalConvertible
{
    @usableFromInline let _minimumTolerance: () -> SchedulerTimeType.Stride
    
    @usableFromInline let _now: () -> SchedulerTimeType
    
    @usableFromInline let _scheduleAfterIntervalToleranceOptionsAction: (
        SchedulerTimeType,
        SchedulerTimeType.Stride,
        SchedulerTimeType.Stride,
        SchedulerOptions?,
        @escaping () -> Void
    ) -> Cancellable
    
    @usableFromInline let _scheduleAfterToleranceOptionsAction: (
        SchedulerTimeType,
        SchedulerTimeType.Stride,
        SchedulerOptions?,
        @escaping () -> Void
    ) -> Void
    
    @usableFromInline let _scheduleOptionsAction: (SchedulerOptions?, @escaping () -> Void) -> Void
}

extension AnyScheduler: Scheduler {
    
    /// The minimum tolerance allowed by the scheduler.
    @inlinable public var minimumTolerance: SchedulerTimeType.Stride { self._minimumTolerance() }

    /// This scheduler’s definition of the current moment in time.
    @inlinable public var now: SchedulerTimeType { self._now() }

    /// Creates a type-erasing scheduler to wrap the provided endpoints.
    ///
    /// - Parameters:
    ///   - minimumTolerance: A closure that returns the scheduler's minimum tolerance.
    ///   - now: A closure that returns the scheduler's current time.
    ///   - scheduleImmediately: A closure that schedules a unit of work to be run as soon as possible.
    ///   - delayed: A closure that schedules a unit of work to be run after a delay.
    ///   - interval: A closure that schedules a unit of work to be performed on a repeating interval.
    public init(
        minimumTolerance: @escaping () -> SchedulerTimeType.Stride,
        now: @escaping () -> SchedulerTimeType,
        scheduleImmediately: @escaping (SchedulerOptions?, @escaping () -> Void) -> Void,
        delayed: @escaping (
            SchedulerTimeType,
            SchedulerTimeType.Stride,
            SchedulerOptions?,
            @escaping () -> Void
        ) -> Void,
        interval: @escaping (
            SchedulerTimeType,
            SchedulerTimeType.Stride,
            SchedulerTimeType.Stride,
            SchedulerOptions?,
            @escaping () -> Void
        ) -> Cancellable
    ) {
        _minimumTolerance = minimumTolerance
        _now = now
        _scheduleOptionsAction = scheduleImmediately
        _scheduleAfterToleranceOptionsAction = delayed
        _scheduleAfterIntervalToleranceOptionsAction = interval
    }
    
    /// Creates a type-erasing scheduler to wrap the provided scheduler.
    ///
    /// - Parameters:
    ///   - scheduler: A scheduler to wrap with a type-eraser.
    public init<S>(_ scheduler: S) where
        S: Scheduler,
        S.SchedulerTimeType == SchedulerTimeType,
        S.SchedulerOptions == SchedulerOptions
    {
        _now = { scheduler.now }
        _minimumTolerance = { scheduler.minimumTolerance }
        _scheduleAfterToleranceOptionsAction = scheduler.schedule
        _scheduleAfterIntervalToleranceOptionsAction = scheduler.schedule
        _scheduleOptionsAction = scheduler.schedule
    }
    
    /// Performs the action at some time after the specified date.
    @inlinable public func schedule(
        after date: SchedulerTimeType,
        tolerance: SchedulerTimeType.Stride,
        options: SchedulerOptions?,
        _ action: @escaping () -> Void
    ) {
        self._scheduleAfterToleranceOptionsAction(date, tolerance, options, action)
    }
    
    /// Performs the action at some time after the specified date, at the
    /// specified frequency, taking into account tolerance if possible.
    @inlinable public func schedule(
        after date: SchedulerTimeType,
        interval: SchedulerTimeType.Stride,
        tolerance: SchedulerTimeType.Stride,
        options: SchedulerOptions?,
        _ action: @escaping () -> Void
    ) -> Cancellable {
        self._scheduleAfterIntervalToleranceOptionsAction(
            date, interval, tolerance, options, action)
    }
    
    /// Performs the action at the next possible opportunity.
    @inlinable public func schedule(
        options: SchedulerOptions?,
        _ action: @escaping () -> Void
    ) {
        self._scheduleOptionsAction(options, action)
    }
}

public extension Strideable where
    Stride: SchedulerTimeIntervalConvertible,
    Stride: ExpressibleByFloatLiteral,
    Stride.FloatLiteralType == Double
{
    @inlinable func advanced(by t: Double) -> Self {
        advanced(by: Stride(floatLiteral: t))
    }
}
#endif
