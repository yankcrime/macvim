" Functions shared by several tests.

" Get the name of the Python executable.
" Also keeps it in s:python.
func PythonProg()
  " This test requires the Python command to run the test server.
  " This most likely only works on Unix and Windows.
  if has('unix')
    " We also need the job feature or the pkill command to make sure the server
    " can be stopped.
    if !(executable('python') && (has('job') || executable('pkill')))
      return ''
    endif
    let s:python = 'python'
  elseif has('win32')
    " Use Python Launcher for Windows (py.exe) if available.
    if executable('py.exe')
      let s:python = 'py.exe'
    elseif executable('python.exe')
      let s:python = 'python.exe'
    else
      return ''
    endif
  else
    return ''
  endif
  return s:python
endfunc

" Run "cmd".  Returns the job if using a job.
func RunCommand(cmd)
  let job = 0
  if has('job')
    let job = job_start(a:cmd, {"stoponexit": "hup"})
    call job_setoptions(job, {"stoponexit": "kill"})
  elseif has('win32')
    exe 'silent !start cmd /c start "test_channel" ' . a:cmd
  else
    exe 'silent !' . a:cmd . '&'
  endif
  return job
endfunc

" Read the port number from the Xportnr file.
func GetPort()
  let l = []
  for i in range(200)
    try
      let l = readfile("Xportnr")
    catch
    endtry
    if len(l) >= 1
      break
    endif
    sleep 10m
  endfor
  call delete("Xportnr")

  if len(l) == 0
    " Can't make the connection, give up.
    return 0
  endif
  return l[0]
endfunc

" Run a Python server for "cmd" and call "testfunc".
" Always kills the server before returning.
func RunServer(cmd, testfunc, args)
  " The Python program writes the port number in Xportnr.
  call delete("Xportnr")

  if len(a:args) == 1
    let arg = ' ' . a:args[0]
  else
    let arg = ''
  endif
  let pycmd = s:python . " " . a:cmd . arg

  try
    let g:currentJob = RunCommand(pycmd)

    " Wait for up to 2 seconds for the port number to be there.
    let port = GetPort()
    if port == 0
      call assert_false(1, "Can't start " . a:cmd)
      return
    endif

    call call(function(a:testfunc), [port])
  catch
    call assert_false(1, "Caught exception: " . v:exception)
  finally
    call s:kill_server(a:cmd)
  endtry
endfunc

func s:kill_server(cmd)
  if has('job')
    if exists('g:currentJob')
      call job_stop(g:currentJob)
      unlet g:currentJob
    endif
  elseif has('win32')
    let cmd = substitute(a:cmd, ".py", '', '')
    call system('taskkill /IM ' . s:python . ' /T /F /FI "WINDOWTITLE eq ' . cmd . '"')
  else
    call system("pkill -f " . a:cmd)
  endif
endfunc

" Wait for up to a second for "expr" to become true.
func WaitFor(expr)
  for i in range(100)
    try
      if eval(a:expr)
	return
      endif
    catch
    endtry
    sleep 10m
  endfor
endfunc
