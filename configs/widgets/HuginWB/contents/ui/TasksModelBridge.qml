import QtQml.Models
import QtQuick
import org.kde.taskmanager as TaskManager

Item {
    id: bridge

    property bool filterByScreen: true
    property var activeTask: null

    readonly property bool hasActiveWindow: activeTask !== null
    readonly property bool activeIsMaximized: hasActiveWindow && activeTask.isMaximized
    readonly property int taskCount: tasksRepeater.count

    function toggleMinimize() {
        if (activeTask)
            activeTask.toggleMinimized();
    }

    function toggleMaximize() {
        if (activeTask)
            activeTask.toggleMaximized();
    }

    function close() {
        if (activeTask)
            activeTask.toggleClose();
    }

    TaskManager.ActivityInfo {
        id: activityInfo
    }

    TaskManager.VirtualDesktopInfo {
        id: virtualDesktopInfo
    }

    TaskManager.TasksModel {
        id: tasksModel

        sortMode: TaskManager.TasksModel.SortVirtualDesktop
        groupMode: TaskManager.TasksModel.GroupDisabled
        activity: activityInfo.currentActivity
        virtualDesktop: virtualDesktopInfo.currentDesktop
        filterByScreen: bridge.filterByScreen
        filterByVirtualDesktop: true
        filterByActivity: true
    }

    Repeater {
        id: tasksRepeater

        model: DelegateModel {
            model: tasksModel

            delegate: Item {
                id: task

                readonly property bool isMaximized: IsMaximized === true
                readonly property bool isActive: IsActive === true

                function modelIndex() {
                    return tasksModel.makeModelIndex(index);
                }

                function toggleMaximized() {
                    tasksModel.requestToggleMaximized(modelIndex());
                }

                function toggleMinimized() {
                    tasksModel.requestToggleMinimized(modelIndex());
                }

                function toggleClose() {
                    tasksModel.requestClose(modelIndex());
                }

                onIsActiveChanged: {
                    if (isActive)
                        bridge.activeTask = task;
                    else if (bridge.activeTask === task)
                        bridge.activeTask = null;
                }
                Component.onDestruction: {
                    if (bridge.activeTask === task)
                        bridge.activeTask = null;
                }
            }
        }
    }
}
