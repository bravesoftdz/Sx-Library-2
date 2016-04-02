unit uThreadPool;

interface

uses
  uTypes, uData, uAsyncTask, Windows, Classes;

// TODO: Wait for task, Priority

type
  TThreads = array of TThread;

  TThreadPool = class
  private
    FMaxThreads: SG;
    FRunThreads: SG;
    FWorking: SG;
    FThreads: TThreads;
    FQueue: TData; // array of TAsyncTask;
    FQueueCriticalSection: TRTLCriticalSection;
    procedure SetRunThreads(Value: SG);
    procedure SetMaxThreads(Value: SG);
    procedure QueueToThread;
    procedure WorkerCreate(const Index: SG);
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddTask(const AAsyncTask: TAsyncTask);
    procedure RandomizeTaskOrder;
    procedure SortTasks(const A: TArrayOfSG);
    function PopAsyncTask: TAsyncTask;
    procedure ClearTasks;
    function RemainTaskCount: UG;
    procedure Pause;
    procedure Resume;
    procedure KillThreads;
    procedure WaitForNoWork;
    procedure WaitForNoThread;
    procedure WorkerStartWork;
    procedure WorkerFinishWork;
    procedure WorkerDestroy(const Index: SG);
    property MaxThreads: SG read FMaxThreads write SetMaxThreads;
  end;

implementation

uses
  Forms, uLog, uSorts, uMath, uSysInfo, uWorkerThread, SysUtils;

{ TThreadPool }

procedure TThreadPool.AddTask(const AAsyncTask: TAsyncTask);
begin
  EnterCriticalSection(FQueueCriticalSection);
  try
    FQueue.Add(AAsyncTask);
  finally
    LeaveCriticalSection(FQueueCriticalSection);
  end;
  QueueToThread;
end;

procedure TThreadPool.ClearTasks;
begin
  EnterCriticalSection(FQueueCriticalSection);
  try
    FQueue.Clear;
  finally
    LeaveCriticalSection(FQueueCriticalSection);
  end;
end;

constructor TThreadPool.Create;
begin
  inherited;

  FQueue := TData.Create;
  InitializeCriticalSection(FQueueCriticalSection);

  FRunThreads := 0;
  SetMaxThreads(GSysInfo.LogicalProcessorCount);
end;

destructor TThreadPool.Destroy;
begin
  EnterCriticalSection(FQueueCriticalSection);
  try
    KillThreads;

    FreeAndNil(FQueue);
  finally
    LeaveCriticalSection(FQueueCriticalSection);
  end;
  DeleteCriticalSection(FQueueCriticalSection);

  inherited;
end;

procedure TThreadPool.Pause;
var
  i: SG;
begin
  for i := 0 to Length(FThreads) - 1 do
    if FThreads[i] <> nil then
      FThreads[i].Suspend;
end;

procedure TThreadPool.QueueToThread;
begin
  if FRunThreads > FWorking then
    Resume;

  if FQueue.Count > (FRunThreads - FWorking) then
    SetRunThreads(FQueue.Count + FWorking);
end;

procedure TThreadPool.RandomizeTaskOrder;
var
  Count: SG;
  i, X: SG;
begin
  EnterCriticalSection(FQueueCriticalSection);
  try
    Count := FQueue.Count;
    if Count <= 1 then
      Exit;
    for i := 0 to Count - 1 do
    begin
      X := Random(Count);
      FQueue.Swap(i, X);
  {		T := FQueue[i];
      FQueue[i] := FQueue[X];
      FQueue[X] := T;}
    end;
  finally
    LeaveCriticalSection(FQueueCriticalSection);
  end;
end;

procedure TThreadPool.Resume;
var
  i: SG;
begin
  for i := 0 to Length(FThreads) - 1 do
    if FThreads[i] <> nil then
      FThreads[i].Resume;
end;

procedure TThreadPool.SetMaxThreads(Value: SG);
begin
  if Value <> FMaxThreads then
  begin
    FMaxThreads := Value;
    QueueToThread;
  end;
end;

procedure TThreadPool.SetRunThreads(Value: SG);
var
  i: SG;
begin
  Value := Range(1, Value, FMaxThreads);
  if Value > FRunThreads then
  begin
    SetLength(FThreads, Value);
    for i := FRunThreads to Value - 1 do
    begin
      WorkerCreate(i);
    end;
  end;
end;

procedure TThreadPool.SortTasks(const A: TArrayOfSG);
var
  AIndex: TArrayOfSG;
  FQueue2: TData;
  i: SG;
  n: SG;
begin
  EnterCriticalSection(FQueueCriticalSection);
  try
    // Sort
    SetLength(AIndex, Length(A));
    FillOrderUG(AIndex[0], Length(AIndex));
    SortS4(False, False, PArraySG(AIndex), PArrayS4(A), Length(AIndex));

    // Add unsorted tasks
    n := FQueue.Count - Length(A);
    FQueue2 := TData.Create;
    for i := 0 to n - 1 do
    begin
      FQueue2.Add(TAsyncTask(FQueue[i]^));
    end;

    // Add sorted tasks
    for i := 0 to Length(A) - 1 do
    begin
      FQueue2.Add(TAsyncTask(FQueue[n + AIndex[i]]^));
    end;

    for i := 0 to FQueue.Count - 1 do
      FQueue.ReplaceObject(i, nil);

  //	FQueue[i] := nil;
    FQueue.Free;
    FQueue := FQueue2;
  finally
    LeaveCriticalSection(FQueueCriticalSection);
  end;
end;

procedure TThreadPool.KillThreads;
begin
  ClearTasks;

  FMaxThreads := 0;
  QueueToThread;
  WaitForNoThread;
end;

procedure TThreadPool.WaitForNoWork;
begin
  while (FQueue.Count > 0) or (FWorking > 0) do
  begin
    Sleep(LoopSleepTime);
    Application.ProcessMessages;
  end;
end;

procedure TThreadPool.WaitForNoThread;
begin
  while (FRunThreads > 0) do
  begin
    Sleep(LoopSleepTime);
    Application.ProcessMessages;
  end;
end;

procedure TThreadPool.WorkerFinishWork;
begin
  InterlockedDecrement(FWorking);
end;

procedure TThreadPool.WorkerStartWork;
begin
  InterlockedIncrement(FWorking);
end;

procedure TThreadPool.WorkerCreate(const Index: SG);
var
  WorkerThread: TWorkerThread;
begin
  WorkerThread := TWorkerThread.Create(Index, Self);
  InterlockedIncrement(FRunThreads);
  FThreads[Index] := WorkerThread;
  WorkerThread.Resume;
end;

procedure TThreadPool.WorkerDestroy(const Index: SG);
begin
  FThreads[Index] := nil; // Write shared object
  InterlockedDecrement(FRunThreads);
end;

function TThreadPool.PopAsyncTask: TAsyncTask;
begin
  EnterCriticalSection(FQueueCriticalSection);
  try
    if FQueue = nil then
      Result := nil
    else
      Result := FQueue.GetAndDeleteFirst as TAsyncTask;
  finally
    LeaveCriticalSection(FQueueCriticalSection);
  end;
end;

function TThreadPool.RemainTaskCount: UG;
begin
  EnterCriticalSection(FQueueCriticalSection);
  try
    Result := FQueue.Count;
  finally
    LeaveCriticalSection(FQueueCriticalSection);
  end;
end;

end.

