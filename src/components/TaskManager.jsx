import React, { useState } from 'react';

function TaskManager({ tasks, onAddTask, onEditTask, onDeleteTask, onSelectTask }) {
  const [isAddingTask, setIsAddingTask] = useState(false);
  const [newTask, setNewTask] = useState({ title: '', content: '' });

  // 处理添加新任务
  const handleAddTask = () => {
    if (newTask.title.trim() && newTask.content.trim()) {
      onAddTask(newTask);
      setNewTask({ title: '', content: '' });
      setIsAddingTask(false);
    }
  };

  // 处理任务选择
  const handleTaskSelect = (task) => {
    onSelectTask(task);
  };

  return (
    <div className="task-manager">
      <div className="task-header">
        <h3>任务管理</h3>
        <button 
          className="btn-add-task"
          onClick={() => setIsAddingTask(!isAddingTask)}
        >
          {isAddingTask ? '取消' : '添加任务'}
        </button>
      </div>

      {/* 添加新任务表单 */}
      {isAddingTask && (
        <div className="add-task-form">
          <input
            type="text"
            placeholder="任务标题"
            value={newTask.title}
            onChange={(e) => setNewTask({ ...newTask, title: e.target.value })}
            className="task-title-input"
          />
          <textarea
            placeholder="任务内容"
            value={newTask.content}
            onChange={(e) => setNewTask({ ...newTask, content: e.target.value })}
            className="task-content-input"
            rows={3}
          />
          <div className="form-buttons">
            <button 
              className="btn-secondary"
              onClick={handleAddTask}
            >
              保存任务
            </button>
            <button 
              className="btn-secondary"
              onClick={() => {
                setNewTask({ title: '', content: '' });
                setIsAddingTask(false);
              }}
            >
              取消
            </button>
          </div>
        </div>
      )}

      {/* 任务列表 */}
      <div className="task-list">
        {tasks.length === 0 ? (
          <div className="empty-tasks">
            <p>暂无任务</p>
            <p className="empty-tasks-hint">点击「添加任务」创建新任务</p>
          </div>
        ) : (
          tasks.map((task) => (
            <div 
              key={task.id} 
              className="task-item"
              onClick={() => handleTaskSelect(task)}
            >
              <div className="task-item-header">
                <h4>{task.title}</h4>
                <div className="task-item-actions">
                  <button 
                    className="btn-action"
                    onClick={(e) => {
                      e.stopPropagation();
                      // 编辑任务逻辑
                    }}
                  >
                    编辑
                  </button>
                  <button 
                    className="btn-action btn-danger"
                    onClick={(e) => {
                      e.stopPropagation();
                      onDeleteTask(task.id);
                    }}
                  >
                    删除
                  </button>
                </div>
              </div>
              <div className="task-item-content">
                <p>{task.content.substring(0, 100)}...</p>
              </div>
              <div className="task-item-meta">
                <span className="task-date">{task.createdAt}</span>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

export default TaskManager;