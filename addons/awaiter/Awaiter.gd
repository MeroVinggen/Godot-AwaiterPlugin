extends EditorPlugin
class_name Awaiter


# waiting all tasks to complete
static func all(tasks: Array) -> _TaskManager:
	# in this case used as also as total
	var required_count: int = tasks.size()
	var task_manger: _TaskManager = _TaskManager.new(required_count, required_count)
	_tasks_runner(tasks, required_count, task_manger)
	return task_manger


# waiting any tasks to complete
static func any(tasks: Array) -> _TaskManager:
	var task_manger: _TaskManager = _TaskManager.new(tasks.size(), 1)
	_tasks_runner(tasks, 1, task_manger)
	return task_manger


# waiting n tasks to complete
static func some(tasks: Array, required_count: int) -> _TaskManager:
	var task_manger: _TaskManager = _TaskManager.new(tasks.size(), required_count)
	_tasks_runner(tasks, required_count, task_manger)
	return task_manger


class _TaskManager:
	signal done(result: Array)
	signal progress(complete: int, total: int)
	
	var _total_count: int
	var _required_count: int
	var _completed_count: int
	var _results: Array
	var _progress_callback: Variant
	
	var is_completed = false
	
	
	func _init(total, required_count: int):
		_total_count = total
		_required_count = total if required_count == -1 else required_count
		_completed_count = 0
		_results = []
	
	
	func task_completed(...data: Array):
		if is_completed:
			return
		
		_completed_count += 1
		_results.append(data)
		
		progress.emit(_completed_count, _total_count)
		
		if _completed_count == _required_count:
			is_completed = true
			done.emit(_results)
			#call_deferred("emit_signal", "done", _results)


static func _tasks_runner(tasks: Array, required_count: int, task_manger: _TaskManager) -> void:
	var tasks_as_callables: Array[Callable] = _prepare_tasks(tasks, task_manger)
	
	# run the tasks
	for task in tasks_as_callables:
		_task_runner(task, task_manger)


static func _task_runner(task: Callable, task_manger: _TaskManager) -> void:
	task_manger.task_completed(await task.call())


# separate callables cll and connect to signals
static func _prepare_tasks(tasks: Array, task_manger: _TaskManager) -> Array[Callable]:
	var callables: Array[Callable] = []
	
	for task in tasks:
		if task is Callable:
			callables.append(task)
		# signal
		else:
			task.connect(task_manger.task_completed, CONNECT_ONE_SHOT)
	
	return callables
