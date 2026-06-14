import Foundation
import HealthKit

/// Reads energy burned from Apple Health and (optionally) writes logged meal
/// nutrition back to it. All calls are no-ops on the simulator without Health data.
final class HealthKitService {
    static let shared = HealthKitService()
    private let store = HKHealthStore()
    private init() {}

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // Types we touch.
    private var activeEnergy: HKQuantityType { HKQuantityType(.activeEnergyBurned) }
    private var restingEnergy: HKQuantityType { HKQuantityType(.basalEnergyBurned) }
    private var dietaryEnergy: HKQuantityType { HKQuantityType(.dietaryEnergyConsumed) }
    private var dietaryProtein: HKQuantityType { HKQuantityType(.dietaryProtein) }
    private var dietaryCarbs: HKQuantityType { HKQuantityType(.dietaryCarbohydrates) }
    private var dietaryFat: HKQuantityType { HKQuantityType(.dietaryFatTotal) }

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        let read: Set<HKObjectType> = [activeEnergy, restingEnergy]
        let write: Set<HKSampleType> = [dietaryEnergy, dietaryProtein, dietaryCarbs, dietaryFat]
        try await store.requestAuthorization(toShare: write, read: read)
    }

    // MARK: Reading energy burned

    /// Total active + resting energy burned (kcal) for the given day.
    func energyBurned(on day: Date = .now) async -> Double {
        guard isAvailable else { return 0 }
        async let active = sumQuantity(activeEnergy, unit: .kilocalorie(), day: day)
        async let resting = sumQuantity(restingEnergy, unit: .kilocalorie(), day: day)
        return await active + (await resting)
    }

    /// Only the active (workout/movement) portion, useful for a separate stat.
    func activeEnergyBurned(on day: Date = .now) async -> Double {
        guard isAvailable else { return 0 }
        return await sumQuantity(activeEnergy, unit: .kilocalorie(), day: day)
    }

    private func sumQuantity(_ type: HKQuantityType, unit: HKUnit, day: Date) async -> Double {
        let (start, end) = Self.dayBounds(day)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type,
                                          quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    // MARK: Writing a meal

    func saveMeal(calories: Int, protein: Double, carbs: Double, fat: Double,
                  date: Date) async throws {
        guard isAvailable else { return }
        var samples: [HKQuantitySample] = []
        func add(_ type: HKQuantityType, _ unit: HKUnit, _ value: Double) {
            guard value > 0 else { return }
            samples.append(HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: value),
                start: date, end: date))
        }
        add(dietaryEnergy, .kilocalorie(), Double(calories))
        add(dietaryProtein, .gram(), protein)
        add(dietaryCarbs, .gram(), carbs)
        add(dietaryFat, .gram(), fat)
        guard !samples.isEmpty else { return }
        try await store.save(samples)
    }

    private static func dayBounds(_ date: Date) -> (Date, Date) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? date
        return (start, end)
    }
}
