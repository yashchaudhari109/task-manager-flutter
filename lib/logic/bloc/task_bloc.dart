import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/models/task_model.dart';
import '../../data/repository/task_repository.dart';

part 'task_event.dart';
part 'task_state.dart';

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final TaskRepository repository;

  TaskBloc(this.repository) : super(TaskInitial()) {
    on<LoadTasks>((event, emit) async {
      emit(TaskLoading());
      try {
        final tasks = await repository.fetchTasks();
        emit(TaskLoaded(tasks));
      } catch (e) {
        emit(TaskError('Failed to load tasks'));
      }
    });

    on<AddTask>((event, emit) async {
      try {
        final newTask = await repository.addTask(event.task);
        if (state is TaskLoaded) {
          final updatedTasks = List<TaskModel>.from((state as TaskLoaded).tasks)
            ..add(newTask);
          emit(TaskLoaded(updatedTasks));
        }
      } catch (_) {
        emit(TaskError('Failed to add task'));
      }
    });

    on<UpdateTask>((event, emit) async {
      try {
        final updatedTask = await repository.updateTask(event.task);
        if (state is TaskLoaded) {
          final updatedTasks = (state as TaskLoaded).tasks.map((task) {
            return task.id == updatedTask.id ? updatedTask : task;
          }).toList();
          emit(TaskLoaded(updatedTasks));
        }
      } catch (_) {
        emit(TaskError('Failed to update task'));
      }
    });

    on<DeleteTask>((event, emit) async {
      try {
        await repository.deleteTask(event.taskId);
        if (state is TaskLoaded) {
          final updatedTasks = (state as TaskLoaded)
              .tasks
              .where((task) => task.id != event.taskId)
              .toList();
          emit(TaskLoaded(updatedTasks));
        }
      } catch (_) {
        emit(TaskError('Failed to delete task'));
      }
    });
  }
}
