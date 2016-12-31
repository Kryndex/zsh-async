#!/usr/bin/env zsh

zmodload zsh/datetime

test__async_job_print_hi() {
	coproc cat
	print -p t

	local IFS=$'\0'
	local out=($(_async_job print hi))
	print $out
	[[ $out[1] == print ]] && [[ $out[2] == 0 ]] && [[ $out[3] = hi ]]
}

test__async_job_wait_for_token() {
	coproc cat

	_async_job print hi &
	job=$!
	start=$EPOCHREALTIME
	{
		sleep 0.1
		print -p t
	} &

	wait $job

	# Fail if the execution time was faster than 0.1 seconds.
	return $(( (EPOCHREALTIME - start) <= 0.1 ))
}

test__async_job_multiple_commands() {
	coproc cat
	print -p t

	local IFS=$'\0'
	local out=($(_async_job 'print -n hi; for i in "1 2" 3 4; do print -n $i; done'))
	print $out

	[[ $out[3] = "hi1 234" ]]
}

test_async_job_multiple_commands_in_string() {
	local -a result
	cb() { result=("$@") }

	async_start_worker test
	async_job test 'print -n "hi  123 "; print -n bye'
	while ! (( ${#result} )); do
		async_process_results test cb
	done

	print $result

	[[ $result[1] = print ]] && [[ $result[3] = "hi  123 bye" ]]
}

test_async_job_git_status() {
	local -a result
	cb() { result=("$@") }

	async_start_worker test
	async_job test git status --porcelain
	while ! async_process_results test cb; do
		sleep 0.1
	done

	print $result

	[[ $result[1] = git ]] && [[ $result[2] == 0 ]] && [[ $result[3] == $(git status --porcelain) ]]
}

test_async_job_multiple_arguments_and_spaces() {
	local -a result
	cb() { result=("$@") }

	async_start_worker test
	async_job test print "hello   world"
	while ! async_process_results test cb; do
		sleep 0.1
	done

	print $result

	[[ $result[1] = print ]] && [[ $result[2] == 0 ]] && [[ $result[3] == "hello   world" ]]
}

test_async_job_unique_worker() {
	local -a result
	cb() {
		# Add to result so we can detect if it was called multiple times.
		result+=("$@")
	}
	helper() {
		sleep 0.1; print $1
	}

	# Start a unique (job) worker.
	async_start_worker test -u

	# Launch two jobs with the same name, the first one should be
	# allowed to complete whereas the second one is never run.
	async_job test helper one
	async_job test helper two

	while ! async_process_results test cb; do
		sleep 0.2
	done

	print $result

	# Ensure that cb was only called once.
	[[ ${#result} = 5 ]] && [[ $result[3] == one ]]
}
