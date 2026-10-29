# -*- coding: utf-8 -*-
<#
    Прогон готового тестирования pr8 (лабораторная работа № 8)
    по данным из таблицы 3 отчёта.

    Скрипт запускает pr8.exe, подаёт ему на stdin те же значения, что
    вводились вручную при тестировании, и печатает стенограмму так, как
    она выглядела бы в консоли: после каждого приглашения видно введённое
    значение.

    Примеры:
        powershell -ExecutionPolicy Bypass -File .\test_pr8.ps1
        powershell -ExecutionPolicy Bypass -File .\test_pr8.ps1 -Test 3
        powershell -ExecutionPolicy Bypass -File .\test_pr8.ps1 -Test 1,2,5-7 -Check
        powershell -ExecutionPolicy Bypass -File .\test_pr8.ps1 -Exe .\x64\Debug\pr8.exe
#>
[CmdletBinding()]
param(
    # Номера тестов: 3, 1,2 или 1-7. Пусто - выполнить все.
    [string[]]$Test = @(),
    # Путь к собранному exe. По умолчанию pr8.exe рядом со скриптом.
    [string]$Exe = '',
    # Сохранить стенограмму в файл (UTF-8).
    [string]$OutFile = '',
    # Проверить, что вывод содержит ожидаемые из отчёта значения.
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$OutputEncoding = [System.Text.Encoding]::UTF8

$Root = $PSScriptRoot
if (-not $Root) { $Root = (Get-Location).Path }

# ---------------------------------------------------------------- параметры программы
# Должны совпадать с константами в pr8.cpp.
$MaxDim = 100
$MinValue = -1000
$MaxValue = 1000
$MenuMax = 5

$PromptRows = "Введите количество строк n число от 1 до ${MaxDim}: "
$PromptCols = "Введите количество столбцов m число от 1 до ${MaxDim}: "
$PromptMenu = "Ваш выбор число от 0 до ${MenuMax}: "

function Get-PromptElement([int]$i, [int]$j) {
    # fillManual печатает "Элемент a", затем i+1 и j+1 без разделителя
    return "Элемент a$i$j число от ${MinValue} до ${MaxValue}: "
}

# ---------------------------------------------------------------- данные тестов (таблица 3)
$cases = @(
    @{
        N = 1
        Title = 'Нормальная ситуация: размер 3x3, ручной ввод'
        Rows = @('3'); Cols = @('3')
        Steps = @(
            @{ Choice = '2'; Values = @('2', '-3', '4', '5', '-6', '7', '-8', '9', '10') }
            @{ Choice = '5' }
            @{ Choice = '0' }
        )
        Expected = @('-8.000', '2.000')
    },
    @{
        N = 2
        Title = 'Нормальная ситуация: размер 2x4, ручной ввод'
        Rows = @('2'); Cols = @('4')
        Steps = @(
            @{ Choice = '2'; Values = @('1', '2', '3', '4', '-5', '6', '-7', '8') }
            @{ Choice = '4' }
            @{ Choice = '5' }
            @{ Choice = '0' }
        )
        Expected = @('-5.000', '3.500')
    },
    @{
        N = 3
        Title = 'Граничная ситуация: отрицательных ниже диагонали нет'
        Rows = @('3'); Cols = @('3')
        Steps = @(
            @{ Choice = '2'; Values = @('1', '2', '3', '4', '5', '6', '7', '8', '9') }
            @{ Choice = '5' }
            @{ Choice = '0' }
        )
        Expected = @('Отрицательных элементов ниже главной диагонали нет', '5.000')
    },
    @{
        N = 4
        Title = 'Граничная ситуация: размер 1x3 (одна строка)'
        Rows = @('1'); Cols = @('3')
        Steps = @(
            @{ Choice = '2'; Values = @('5', '-2', '3') }
            @{ Choice = '5' }
            @{ Choice = '0' }
        )
        Expected = @('Отрицательных элементов ниже главной диагонали нет', '5.000')
    },
    @{
        N = 5
        Title = 'Граничная ситуация: размер 3x2 (строк больше, чем столбцов)'
        Rows = @('3'); Cols = @('2')
        Steps = @(
            @{ Choice = '2'; Values = @('1', '2', '-3', '4', '-5', '-6') }
            @{ Choice = '5' }
            @{ Choice = '0' }
        )
        Expected = @('-4.667', '2.500')
    },
    @{
        N = 6
        Title = 'Исключительная ситуация: массив ещё не заполнен'
        Rows = @('3'); Cols = @('3')
        Steps = @(
            @{ Choice = '4' }
            @{ Choice = '5' }
            @{ Choice = '0' }
        )
        Expected = @('Массив ещё не заполнен.')
    },
    @{
        N = 7
        Title = 'Исключительная ситуация: неверный ввод размеров'
        Rows = @('150', '3'); Cols = @('abc', '3')
        Steps = @(
            @{ Choice = '0' }
        )
        Expected = @('Ошибка: число вне допустимого диапазона.', 'Ошибка: нужно ввести целое число.')
    }
)

# ---------------------------------------------------------------- поиск exe
function Resolve-Program([string]$path) {
    if ($path) {
        if (-not (Test-Path -LiteralPath $path)) { throw "Не найден файл: $path" }
        return (Resolve-Path -LiteralPath $path).Path
    }
    $candidates = @(
        (Join-Path $Root 'pr8.exe'),
        (Join-Path $Root 'x64\Debug\pr8.exe'),
        (Join-Path $Root 'x64\Release\pr8.exe')
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { return (Resolve-Path -LiteralPath $c).Path }
    }
    throw "Не найден pr8.exe. Соберите решение в Visual Studio или укажите путь: -Exe <путь к exe>"
}

# ---------------------------------------------------------------- подготовка шагов
function Get-CasePlan($case) {
    $schedule = New-Object System.Collections.ArrayList
    $lines = New-Object System.Collections.ArrayList
    $n = 0
    $m = 0

    foreach ($v in $case.Rows) {
        [void]$schedule.Add(@($PromptRows, [string]$v))
        [void]$lines.Add([string]$v)
        if ($v -match '^\d+$') { $n = [int]$v }
    }
    foreach ($v in $case.Cols) {
        [void]$schedule.Add(@($PromptCols, [string]$v))
        [void]$lines.Add([string]$v)
        if ($v -match '^\d+$') { $m = [int]$v }
    }
    if ($n -le 0 -or $m -le 0) { throw "Тест $($case.N): не удалось определить размеры матрицы." }

    foreach ($step in $case.Steps) {
        $choice = [string]$step.Choice
        [void]$schedule.Add(@($PromptMenu, $choice))
        [void]$lines.Add($choice)

        if ($choice -eq '2') {
            $values = @($step.Values)
            $need = $n * $m
            if ($values.Count -ne $need) {
                throw "Тест $($case.N): для матрицы ${n}x${m} нужно $need значений, передано $($values.Count)."
            }
            $k = 0
            for ($i = 1; $i -le $n; $i++) {
                for ($j = 1; $j -le $m; $j++) {
                    [void]$schedule.Add(@((Get-PromptElement $i $j), [string]$values[$k]))
                    [void]$lines.Add([string]$values[$k])
                    $k++
                }
            }
        }
        elseif ($choice -eq '1') {
            throw "Тест $($case.N): пункт меню 1 (повторный ввод размеров) в скрипте не описан."
        }
    }

    return @{ Schedule = $schedule; Lines = $lines }
}

# ---------------------------------------------------------------- запуск программы
function Invoke-Case($exe, $plan) {
    # Ввод подаём через файл и перенаправление cmd: при кодовой странице 65001
    # перенаправленный stdin-поток .NET добавляет BOM, и cin не читает первое число.
    $inFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(),
        'pr8_test_' + [guid]::NewGuid().ToString('N') + '.txt')
    try {
        $payload = (($plan.Lines -join "`r`n") + "`r`n")
        [System.IO.File]::WriteAllText($inFile, $payload, (New-Object System.Text.UTF8Encoding($false)))

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $env:ComSpec
        $psi.Arguments = '/d /c ""{0}" < "{1}""' -f $exe, $inFile
        $psi.WorkingDirectory = $Root
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8

        $p = [System.Diagnostics.Process]::Start($psi)
        try {
            $out = $p.StandardOutput.ReadToEnd()
            $p.WaitForExit()
            $exitCode = $p.ExitCode
        }
        finally {
            $p.Dispose()
        }
    }
    finally {
        if (Test-Path -LiteralPath $inFile) { Remove-Item -LiteralPath $inFile -Force -ErrorAction SilentlyContinue }
    }
    return @{ Output = $out; ExitCode = $exitCode }
}

# ---------------------------------------------------------------- вставка введённых значений в вывод
function Merge-Transcript([string]$raw, $schedule) {
    $sb = New-Object System.Text.StringBuilder
    $pos = 0
    foreach ($pair in $schedule) {
        $prompt = [string]$pair[0]
        $value = [string]$pair[1]
        $idx = $raw.IndexOf($prompt, $pos, [System.StringComparison]::Ordinal)
        if ($idx -lt 0) {
            throw "Не найдено приглашение в выводе программы: '$prompt' (позиция $pos)."
        }
        $end = $idx + $prompt.Length
        [void]$sb.Append($raw.Substring($pos, $end - $pos))
        [void]$sb.Append($value).Append("`r`n")
        $pos = $end
    }
    [void]$sb.Append($raw.Substring($pos))
    return $sb.ToString()
}

# ---------------------------------------------------------------- выбор тестов
function Get-SelectedCases($filter) {
    if (-not $filter -or $filter.Count -eq 0) { return $cases }

    $ids = New-Object System.Collections.ArrayList
    foreach ($item in $filter) {
        foreach ($part in ($item -split '[,;\s]+')) {
            if (-not $part) { continue }
            if ($part -match '^(\d+)-(\d+)$') {
                $from = [int]$Matches[1]; $to = [int]$Matches[2]
                for ($k = $from; $k -le $to; $k++) { [void]$ids.Add($k) }
            }
            elseif ($part -match '^\d+$') { [void]$ids.Add([int]$part) }
            else { throw "Неверный номер теста: '$part' (ожидается, например, 3 или 1,2,5-7)." }
        }
    }
    $selected = @()
    foreach ($id in ($ids | Select-Object -Unique)) {
        $found = $cases | Where-Object { $_.N -eq $id }
        if (-not $found) {
            $available = ($cases | ForEach-Object { $_.N }) -join ', '
            throw "Теста $id нет. Доступные тесты: $available."
        }
        $selected += $found
    }
    return $selected
}

# ---------------------------------------------------------------- вывод
function Write-Line([string]$text) { [Console]::WriteLine($text) }

$exePath = Resolve-Program $Exe
$sourcePath = Join-Path $Root 'pr8.cpp'
if ((Test-Path -LiteralPath $sourcePath) -and
    ((Get-Item -LiteralPath $exePath).LastWriteTime -lt (Get-Item -LiteralPath $sourcePath).LastWriteTime)) {
    Write-Line "Внимание: pr8.exe старше pr8.cpp — пересоберите проект, иначе вывод может не совпадать с отчётом."
}

$selected = @(Get-SelectedCases $Test)
$transcript = New-Object System.Text.StringBuilder
$failed = 0

Write-Line "Программа: $exePath"
Write-Line "Тестов к выполнению: $($selected.Count)"
Write-Line ""

foreach ($case in $selected) {
    $plan = Get-CasePlan $case
    $run = Invoke-Case $exePath $plan
    $text = Merge-Transcript $run.Output $plan.Schedule

    [void]$transcript.AppendLine("===== Тест $($case.N). $($case.Title) =====")
    [void]$transcript.Append($text)
    if (-not $text.EndsWith("`n")) { [void]$transcript.AppendLine() }
    [void]$transcript.AppendLine()

    Write-Line "===== Тест $($case.N). $($case.Title) ====="
    [Console]::Write($text)
    if (-not $text.EndsWith("`n")) { Write-Line "" }

    if ($Check) {
        $missing = @()
        foreach ($pattern in $case.Expected) {
            if (-not $run.Output.Contains($pattern)) { $missing += $pattern }
        }
        if ($missing.Count -eq 0) {
            Write-Line "  [OK] вывод содержит ожидаемые значения из отчёта"
        }
        else {
            $failed++
            Write-Line ("  [НЕ СОВПАЛО] не найдено: " + ($missing -join '; '))
        }
    }
    Write-Line ""
}

Write-Line "Готово: выполнено тестов — $($selected.Count)."
if ($Check -and $failed -eq 0) { Write-Line "Проверка: все тесты совпали с ожидаемыми значениями отчёта." }
if ($Check -and $failed -gt 0) { Write-Line "Проверка: тестов с расхождениями — $failed." }

if ($OutFile) {
    if ([System.IO.Path]::IsPathRooted($OutFile)) { $full = $OutFile }
    else { $full = Join-Path (Get-Location).Path $OutFile }
    [System.IO.File]::WriteAllText($full, $transcript.ToString(), (New-Object System.Text.UTF8Encoding($false)))
    Write-Line "Стенограмма сохранена: $full"
}

if ($Check -and $failed -gt 0) { exit 1 }
