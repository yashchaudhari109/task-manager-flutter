import '../../core/services/api_service.dart';
import '../../data/models/task_model.dart';

class TaskRepository {
  final ApiService _apiService;

  TaskRepository(this._apiService);

  Future<List<TaskModel>> fetchTasks() async {
    final response = await _apiService.get('/tasks');
    final List data = response.data ?? [];
    return data.map((e) => TaskModel.fromJson(e)).toList();
  }

  Future<TaskModel> addTask(TaskModel task) async {
    final response = await _apiService.post('/tasks', data: task.toJson());
    return TaskModel.fromJson(response.data);
  }

  Future<TaskModel> updateTask(TaskModel task) async {
    final response =
        await _apiService.put('/tasks/${task.id}', data: task.toJson());
    return TaskModel.fromJson(response.data);
  }

  Future<void> deleteTask(String id) async {
    await _apiService.delete('/tasks/$id');
  }
}
