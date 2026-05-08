import Foundation
import BackgroundTasks

public enum BackgroundRefresh {
    /// Must match the value you add to Info.plist under BGTaskSchedulerPermittedIdentifiers.
    public static let taskID = "Joshua-Cohen.NextStop.refresh"

    public static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: nil) { task in
            handle(task: task as! BGAppRefreshTask)
        }
    }

    public static func schedule() {
        let req = BGAppRefreshTaskRequest(identifier: taskID)
        req.earliestBeginDate = Date().addingTimeInterval(15 * 60)
        do { try BGTaskScheduler.shared.submit(req) } catch {
            // No-op: scheduling fails on simulator and when too many tasks queued.
        }
    }

    private static func handle(task: BGAppRefreshTask) {
        // Always reschedule the next one before doing work, so a crash doesn't
        // permanently disable background refresh.
        schedule()

        let work = Task {
            await RefreshCoordinator.shared.refresh(reason: .backgroundTask)
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
