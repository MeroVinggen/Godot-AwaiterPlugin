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


class _TaskManager extends RefCounted:
	signal done(result: Array)
	signal progress(complete: int, total: int)
	
	var _total_count: int
	var _required_count: int
	var _completed_count: int
	var _results: Array
	var _progress_callback: Variant
	
	var is_done = false
	
	
	func _init(total, required_count: int):
		_total_count = total
		_required_count = total if required_count == -1 else required_count
		_completed_count = 0
		_results = []
		
		reference()
	
	
	func task_completed(...data: Array):
		if is_done:
			return
		
		_completed_count += 1
		_results.append(data)
		
		progress.emit(_completed_count, _total_count)
		
		if _completed_count == _required_count:
			is_done = true
			done.emit(_results)
			unreference()


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


# await n process frames
static func process_frames(target_frames_count: int) -> _FramesAwaiter:
	return _FramesAwaiter.new(target_frames_count, Engine.get_main_loop().process_frame)


# await n physics frames
static func physics_frames(target_frames_count: int) -> _FramesAwaiter:
	return _FramesAwaiter.new(target_frames_count, Engine.get_main_loop().physics_frame)



class _FramesAwaiter extends RefCounted:
	signal done()
	signal progress(passed_frames: int, target_frames: int)
	
	var _passed_frames_count: int = 0
	var _target_frames_count: int
	var _frame_signal: Signal
	
	var is_done = false
	
	
	func _init(target_frames_count: int, frame_signal: Signal):
		_target_frames_count = target_frames_count
		_frame_signal = frame_signal
		
		reference()
		
		frame_signal.connect(_on_frame)
	
	
	func _on_frame() -> void:
		_passed_frames_count += 1
		progress.emit(_passed_frames_count, _target_frames_count)
		
		if _passed_frames_count >= _target_frames_count:
			is_done = true
			_frame_signal.disconnect(_on_frame)
			done.emit()
			unreference()
