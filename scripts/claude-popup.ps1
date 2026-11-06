# Claude Code Popup: eigenes Benachrichtigungsfenster fuer Stop-, Notification- und PreToolUse-Hooks.
# Erscheint auch bei "Nicht stoeren", unten rechts auf dem Monitor mit dem Mauszeiger.
# Aufruf durch hooks/hooks.json: powershell.exe -File claude-popup.ps1 -Event Stop|Notification|Question  (Hook-JSON auf stdin)
# Selbsttest ohne Claude: powershell.exe -NoProfile -ExecutionPolicy Bypass -File claude-popup.ps1 -Event Stop -Test
param([string]$Event = "Notification", [switch]$Test)

$ErrorActionPreference = 'SilentlyContinue'

# --- Einstellungen, aenderbar ueber Umgebungsvariablen (z. B. in .claude/settings.json unter "env") ---
# CLAUDE_POPUP_SECONDS        Anzeigedauer, wenn Claude fertig ist, in Sekunden (Standard 10)
# CLAUDE_POPUP_WAIT_SECONDS   Anzeigedauer, wenn Claude auf dich wartet (Standard 30)
#                             Beide 0 = bleibt bis zum Klick stehen, hoechstens 5 Minuten
# CLAUDE_POPUP_ALWAYS         1 = auch melden, wenn das Terminal der Session schon im Vordergrund ist
# CLAUDE_POPUP_MAX            Hoechstzahl gleichzeitig sichtbarer Karten (Standard 4)
function Get-CPNum([string]$name, [int]$fallback) {
  $v = [Environment]::GetEnvironmentVariable($name)
  if ($v -and $v -match '^\s*\d+\s*$') { return [int]$v.Trim() }
  return $fallback
}
$global:cpMax = Get-CPNum 'CLAUDE_POPUP_MAX' 4
if ($global:cpMax -lt 1) { $global:cpMax = 1 }
$cpAlways = ($env:CLAUDE_POPUP_ALWAYS -eq '1') -or $Test

# Protokoll zur Fehlersuche: %TEMP%\claude-popup.log, rund 300 KB, danach wandert es nach
# claude-popup.log.alt. Jede Zeile traegt die PID, weil mehrere Karten gleichzeitig schreiben koennen.
$global:cpLog = Join-Path $env:TEMP 'claude-popup.log'
# Schreiben kann scheitern, wenn mehrere Karten gleichzeitig protokollieren: ein paar Versuche genuegen.
function global:Write-CPLog([string]$m) {
  $line = "$(Get-Date -Format 'dd.MM. HH:mm:ss') [$PID] $m"
  for ($i = 0; $i -lt 10; $i++) {
    try { Add-Content -LiteralPath $global:cpLog -Value $line -ErrorAction Stop; return } catch { Start-Sleep -Milliseconds 20 }
  }
}
# Rotation per Umbenennen: das frueher benutzte Lesen-und-Neuschreiben verlor Zeilen anderer Prozesse
# und konnte an der offenen Datei scheitern.
try {
  $fi = Get-Item -LiteralPath $global:cpLog -ErrorAction Stop
  if ($fi.Length -gt 300000) { Move-Item -LiteralPath $global:cpLog -Destination "$($global:cpLog).alt" -Force -ErrorAction Stop }
} catch {}
if ($Test) { Write-CPLog "----- Event $Event (Testmodus)" } else { Write-CPLog "----- Event $Event" }

# --- Hook-Daten von stdin lesen ---
[Console]::InputEncoding = [Text.Encoding]::UTF8
$data = $null
# Im Testmodus nichts von stdin lesen: von Hand gestartet wuerde ReadToEnd endlos warten.
if (-not $Test) { try { $data = [Console]::In.ReadToEnd() | ConvertFrom-Json } catch {} }

$cwd = if ($data.cwd) { $data.cwd } else { (Get-Location).Path }
$Project = Split-Path $cwd -Leaf
if (-not $Project) { $Project = $cwd }

if ($Event -eq 'Stop') {
  $Title  = "Claude ist fertig"
  $Detail = "Die Antwort ist bereit."
  if ($data.last_assistant_message) {
    $line = (($data.last_assistant_message -split "`n") | Where-Object { $_.Trim() } | Select-Object -First 1)
    $line = ($line -replace '[#*`>_]', '').Trim()
    if ($line.Length -gt 110) { $line = $line.Substring(0, 107) + "..." }
    if ($line) { $Detail = $line }
  }
} elseif ($Event -eq 'Question') {
  # PreToolUse fuer AskUserQuestion und ExitPlanMode: Claude wartet auf eine Antwort
  if ($data.tool_name -eq 'ExitPlanMode') {
    $Title  = "Claude hat einen Plan fertig"
    $Detail = "Schau dir den Plan an und gib ihn frei."
  } else {
    $Title  = "Claude hat eine Frage"
    $Detail = "Claude wartet auf deine Antwort."
    $q = @($data.tool_input.questions)[0].question
    if ($q) { $Detail = $q }
  }
} else {
  switch ($data.notification_type) {
    'permission_prompt' { $Title = "Claude braucht deine Freigabe" }
    'idle_prompt'       { $Title = "Claude wartet auf dich" }
    default             { $Title = "Claude braucht dich" }
  }
  $Detail = if ($data.message) { $data.message } else { "Schau kurz in die Session." }
}

if ($Test) {
  $Title  = "Testpopup"
  $Detail = "Siehst du diese Karte, funktioniert das Popup. Monitor und Position stehen im Protokoll."
}

Write-CPLog "Titel '$Title', Projekt '$Project', Session '$("$($data.session_id)".Split('-')[0])'"

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms
Add-Type -Namespace CP -Name Win -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern bool FreeConsole();
[DllImport("kernel32.dll")] public static extern bool AttachConsole(uint pid);
[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint f);
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
[DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
public static string Describe(IntPtr h) {
  if (h == IntPtr.Zero) return "0";
  uint pid; GetWindowThreadProcessId(h, out pid);
  var sb = new System.Text.StringBuilder(256); GetWindowText(h, sb, 256);
  string name = "?"; try { name = System.Diagnostics.Process.GetProcessById((int)pid).ProcessName; } catch {}
  return h.ToString() + " (" + name + " " + pid + ", sichtbar " + IsWindowVisible(h) + ", Titel '" + sb + "')";
}
'@

# --- Fenster der Session finden ---
# Vorfahren dieses Prozesses sammeln. Begrenzt, weil PID 0 sich selbst als Eltern hat;
# ein Eltern-Prozess, der juenger ist als das Kind, ist eine wiederverwendete PID und zaehlt nicht.
$chain = @()
$p = Get-CimInstance Win32_Process -Filter "ProcessId=$PID"
while ($p -and $chain.Count -lt 20) {
  $chain += $p
  if ($p.ParentProcessId -eq 0 -or $p.ParentProcessId -eq $p.ProcessId) { break }
  $parent = Get-CimInstance Win32_Process -Filter "ProcessId=$($p.ParentProcessId)"
  if ($parent -and $parent.CreationDate -gt $p.CreationDate) { break }
  $p = $parent
}

$global:cpTarget = [IntPtr]::Zero
$isTerminal = $false
$isDesktop = $false

# 1. Terminal: Besitzerfenster der Konsole von claude.exe (z. B. das Windows-Terminal-Fenster).
#    Ist es unsichtbar, ist es eine Pseudokonsole ohne Besitzer (VS Code, Claude Desktop, andere Terminals)
#    und taugt nicht als Ziel, SetForegroundWindow darauf bewirkt nichts.
$cli = $chain | Where-Object { $_.Name -eq 'claude.exe' } | Select-Object -First 1
if ($cli) {
  [CP.Win]::FreeConsole() | Out-Null
  if ([CP.Win]::AttachConsole([uint32]$cli.ProcessId)) {
    $h = [CP.Win]::GetAncestor([CP.Win]::GetConsoleWindow(), 3)
    [CP.Win]::FreeConsole() | Out-Null
    Write-CPLog "Konsole von claude.exe $($cli.ProcessId): $([CP.Win]::Describe($h))"
    if ($h -ne [IntPtr]::Zero -and [CP.Win]::IsWindowVisible($h)) { $global:cpTarget = $h; $isTerminal = $true }
  }
}

# 2. Sonst das erste Vorfahren-Fenster: VS Code, Claude Desktop oder ein anderes Terminal
if ($global:cpTarget -eq [IntPtr]::Zero) {
  foreach ($a in ($chain | Select-Object -Skip 1)) {
    if ($a.Name -eq 'explorer.exe') { break }
    $proc = Get-Process -Id $a.ProcessId
    if ($proc -and $proc.MainWindowHandle -ne [IntPtr]::Zero) {
      $global:cpTarget = $proc.MainWindowHandle
      $isDesktop = $a.Name -eq 'claude.exe'
      break
    }
  }
}

# 3. Letzter Ausweg: irgendein Fenster von Claude Desktop
if ($global:cpTarget -eq [IntPtr]::Zero) {
  $desk = Get-Process claude | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1
  if ($desk) { $global:cpTarget = $desk.MainWindowHandle; $isDesktop = $true }
}

Write-CPLog "Vorfahren: $(($chain | ForEach-Object { "$($_.Name) $($_.ProcessId)" }) -join ' > ')"
Write-CPLog "Ziel: $([CP.Win]::Describe($global:cpTarget)), Terminal $isTerminal, Desktop $isDesktop"
Write-CPLog "Vordergrund: $([CP.Win]::Describe([CP.Win]::GetForegroundWindow()))"

# Kein Popup, wenn das Terminal der Session vorne ist und Claude nur fertig ist.
# Wartet Claude auf eine Antwort, kommt das Popup trotzdem: das Fenster kann vorne sein, waehrend
# darin ein anderer Tab sichtbar ist, und dann sieht man die Anfrage nicht.
# Nicht fuer Claude Desktop: dort laufen mehrere Sessions im selben Fenster, das sichtbare Projekt ist nicht erkennbar.
if ($isTerminal -and $Event -eq 'Stop' -and -not $cpAlways -and [CP.Win]::GetForegroundWindow() -eq $global:cpTarget) {
  Write-CPLog "Terminal ist vorne und Claude ist nur fertig, kein Popup (CLAUDE_POPUP_ALWAYS=1 zeigt es trotzdem)"
  exit 0
}

# --- Stapel: jede Karte meldet sich mit einer Datei in %TEMP%\claude-popup an ---
# Inhalt: Session|Zeit|Hoehe|Startzeit des Prozesses. Neueste Karte unten, aeltere darueber.
# Hoechstens CLAUDE_POPUP_MAX Karten; meldet sich dieselbe Session erneut, weicht ihre alte Karte.
$global:cpDir = Join-Path $env:TEMP 'claude-popup'
New-Item -ItemType Directory -Force $global:cpDir | Out-Null
# Im Testmodus zuerst haengengebliebene Karten entfernen: solche Karten koennen neue Popups blockieren.
if ($Test) {
  $alt = @(Get-ChildItem $global:cpDir -Filter '*.card')
  if ($alt.Count) { $alt | Remove-Item -Force; Write-CPLog "Testmodus: $($alt.Count) vorhandene Karten entfernt" }
}
$global:cpFile = Join-Path $global:cpDir "$PID.card"
$global:cpSession = "$($data.session_id)"
$global:cpCreated = [DateTime]::UtcNow.Ticks
# Startzeit des eigenen Prozesses. Sie steht im vierten Feld der Karte, damit spaetere Popups
# erkennen, ob diese PID noch derselbe Prozess ist.
$global:cpBorn = [long]0
try { $global:cpBorn = (Get-Process -Id $PID).StartTime.Ticks } catch {}

function global:Get-CPCards {
  $now = [DateTime]::UtcNow
  $cards = foreach ($f in Get-ChildItem $global:cpDir -Filter '*.card') {
    $cpid = 0
    if (-not [int]::TryParse($f.BaseName, [ref]$cpid)) { continue }
    $parts = "$(Get-Content $f.FullName -TotalCount 1)" -split '\|'
    if ($parts.Count -lt 3) {
      # Karte wird gerade erst geschrieben: nur wegwerfen, wenn sie schon eine Weile unvollstaendig ist
      if ($f.LastWriteTimeUtc -lt $now.AddSeconds(-10)) { Remove-Item $f.FullName }
      continue
    }
    if ($cpid -ne $PID) {
      # Aufraeumen, wenn der Prozess weg ist. Die Startzeit entlarvt eine neu vergebene PID:
      # ohne diese Pruefung konnten alte Karten (etwa nach einem Neustart) jedes neue Popup blockieren,
      # weil zufaellig wieder ein powershell-Prozess dieselbe PID hatte.
      $own = Get-Process -Id $cpid
      $born = [long]0
      if ($parts.Count -ge 4) { [long]::TryParse($parts[3], [ref]$born) | Out-Null }
      $same = $own -and ($born -eq 0 -or [math]::Abs($own.StartTime.Ticks - $born) -lt 20000000)
      # Zweites Netz: der Notaus schliesst jedes Fenster nach 5 Minuten, danach ist jede Karte ueberfaellig.
      $stale = $f.LastWriteTimeUtc -lt $now.AddMinutes(-6)
      if (-not $same -or $stale) { Remove-Item $f.FullName; continue }
    }
    [pscustomobject]@{ Pid = $cpid; Session = $parts[0]; Created = [long]$parts[1]; Height = [double]$parts[2] }
  }
  @($cards | Sort-Object Created, Pid -Descending)
}

# Zielposition dieser Karte als @(Top, Platz), oder $null, wenn sie weichen muss
function global:Get-CPSlot {
  $offset = 0; $i = 0; $mine = $false
  foreach ($c in Get-CPCards) {
    if ($c.Pid -eq $PID) { $mine = $true; break }
    if ($global:cpSession -and $c.Session -eq $global:cpSession) { return $null }
    $offset += $c.Height - 26   # Fensterhoehe minus Schattenrand (2 x 18), plus 10 px Abstand
    $i++
  }
  # Ohne eigene Karte (Anmeldung fehlgeschlagen) gilt diese Karte als die neueste, statt sich von
  # fremden Karten verdraengen zu lassen. Zwei Karten uebereinander sind besser als gar kein Popup.
  if (-not $mine) { return @(($global:cpBottom - $global:cpH), 0) }
  if ($i -ge $global:cpMax) { return $null }
  return @(($global:cpBottom - $global:cpH - $offset), $i)
}

[xml]$xaml = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Margin="18" CornerRadius="8" Background="#2B2B2B" BorderBrush="#3D3D3D" BorderThickness="1">
  <Border.Effect><DropShadowEffect BlurRadius="30" ShadowDepth="6" Direction="270" Opacity="0.5" Color="Black"/></Border.Effect>
  <Border.Resources>
    <Style x:Key="Ghost" TargetType="Button">
      <Setter Property="Foreground" Value="#C8C8C8"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template"><Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="bg" Background="Transparent" CornerRadius="4"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bg" Property="Background" Value="#3A3A3A"/><Setter Property="Foreground" Value="#FFFFFF"/></Trigger>
            <Trigger Property="IsPressed" Value="True"><Setter TargetName="bg" Property="Background" Value="#333333"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value></Setter>
    </Style>
    <Style x:Key="Primary" TargetType="Button">
      <Setter Property="Foreground" Value="#FFFFFF"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template"><Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="bg" Background="#383838" BorderBrush="#474747" BorderThickness="1" CornerRadius="4"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bg" Property="Background" Value="#424242"/></Trigger>
            <Trigger Property="IsPressed" Value="True"><Setter TargetName="bg" Property="Background" Value="#323232"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value></Setter>
    </Style>
  </Border.Resources>
  <Grid Margin="16,12,10,16">
    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
    <Grid Grid.Row="0">
      <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,40,0">
        <Ellipse Width="7" Height="7" Fill="#D97757" VerticalAlignment="Center" Margin="0,1,8,0"/>
        <TextBlock Text="Claude Code" Foreground="#A8A8A8" FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="12"/>
        <TextBlock x:Name="ProjectText" Foreground="#787878" FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="12" TextTrimming="CharacterEllipsis"/>
      </StackPanel>
      <Button x:Name="Done" Style="{StaticResource Ghost}" Width="30" Height="28" HorizontalAlignment="Right" ToolTip="Erledigt">
        <TextBlock Text="&#xE73E;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="13"/>
      </Button>
    </Grid>
    <StackPanel Grid.Row="1" Margin="0,6,6,0">
      <TextBlock x:Name="TitleText" Foreground="#FFFFFF" FontFamily="Segoe UI Variable Display, Segoe UI" FontWeight="SemiBold" FontSize="15"/>
      <TextBlock x:Name="DetailText" Foreground="#BEBEBE" FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="13" TextWrapping="Wrap" MaxHeight="54" TextTrimming="CharacterEllipsis" Margin="0,3,0,0"/>
    </StackPanel>
    <Button x:Name="Open" Grid.Row="2" Style="{StaticResource Primary}" Height="32" Margin="0,14,6,0">
      <StackPanel Orientation="Horizontal">
        <TextBlock Text="&#xE8A7;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="12" VerticalAlignment="Center" Margin="0,1,8,0"/>
        <TextBlock x:Name="OpenText" Text="Zur Session" FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="13" VerticalAlignment="Center"/>
      </StackPanel>
    </Button>
    <TextBlock x:Name="Hint" Grid.Row="2" Visibility="Collapsed" Foreground="#9A9A9A" FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="12" TextWrapping="Wrap" Margin="0,12,6,0"/>
  </Grid>
</Border>
'@

$content = [System.Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$content.FindName('ProjectText').Text = "  $([char]0xB7)  $Project"
$content.FindName('TitleText').Text   = $Title
$content.FindName('DetailText').Text  = $Detail
# Claude Desktop laesst sich nur als Fenster nach vorne holen, nicht auf einen bestimmten Chat umschalten
if ($isDesktop) { $content.FindName('OpenText').Text = "Claude $([char]0xF6)ffnen" }
# Ist Claude Desktop schon vorne, koennte der Button nichts tun, also stattdessen sagen, wohin man wechseln muss
if ($isDesktop -and [CP.Win]::GetForegroundWindow() -eq $global:cpTarget) {
  $content.FindName('Open').Visibility = 'Collapsed'
  $hint = $content.FindName('Hint')
  $hint.Text = "Wechsle in der Seitenleiste zu $Project."
  $hint.Visibility = 'Visible'
  Write-CPLog "Claude Desktop ist vorne, Hinweis statt Button"
}

# Position vor dem Anzeigen berechnen (wichtig bei mehreren Monitoren mit Skalierung)
$W = 400
$content.Measure((New-Object System.Windows.Size($W, [double]::PositiveInfinity)))
$H = [math]::Ceiling($content.DesiredSize.Height)
$scr   = [System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Cursor]::Position)
if (-not $scr) { $scr = [System.Windows.Forms.Screen]::PrimaryScreen; Write-CPLog "Monitor unter der Maus nicht ermittelbar, nehme den Hauptmonitor" }
$scale = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width / [System.Windows.SystemParameters]::PrimaryScreenWidth
# Ohne Notbremse wuerde eine 0 hier das Popup still durch eine Division mit Null beenden
if (-not ($scale -gt 0)) { Write-CPLog "Skalierung nicht ermittelbar, nehme 1"; $scale = 1 }
$wa = $scr.WorkingArea
$global:cpLeft = ($wa.Right / $scale) - $W

$win = New-Object System.Windows.Window
$win.WindowStyle = 'None'; $win.AllowsTransparency = $true; $win.Background = 'Transparent'
$win.Topmost = $true; $win.ShowInTaskbar = $false; $win.ShowActivated = $false
$win.WindowStartupLocation = 'Manual'
$win.Width = $W; $win.Height = $H
$global:cpH = $H
$global:cpBottom = $wa.Bottom / $scale
Write-CPLog "Monitor $($scr.DeviceName), Arbeitsflaeche $($wa.Width)x$($wa.Height) bei $($wa.X),$($wa.Y), Skalierung $scale, Karte $W x $H"
# Liest gerade eine andere Karte, kann das Schreiben scheitern: kurz warten und erneut versuchen
for ($try = 0; $try -lt 5 -and -not (Test-Path $global:cpFile); $try++) {
  Set-Content $global:cpFile "$($global:cpSession)|$($global:cpCreated)|$H|$($global:cpBorn)"
  if (-not (Test-Path $global:cpFile)) { Start-Sleep -Milliseconds 50 }
}
if (-not (Test-Path $global:cpFile)) { Write-CPLog "Warnung: eigene Karte konnte nicht angemeldet werden" }
$slot = Get-CPSlot
$global:cpSlotIdx = if ($slot) { $slot[1] } else { -1 }
$global:cpTop = if ($slot) { $slot[0] } else { $global:cpBottom - $H }
# Sicherheitsnetz: nie ausserhalb der Arbeitsflaeche landen, sonst waere das Popup unsichtbar.
if ($global:cpTop -lt ($wa.Y / $scale)) { $global:cpTop = $wa.Y / $scale }
if ($global:cpLeft -lt ($wa.X / $scale)) { $global:cpLeft = $wa.X / $scale }
$global:cpShown = [DateTime]::UtcNow
$global:cpPlace = 0
$win.Top = $global:cpTop; $win.Left = $global:cpLeft + 40
$win.Opacity = 0
$win.Content = $content
$global:cpWin = $win
$global:cpContent = $content
$global:cpEase = New-Object System.Windows.Media.Animation.CubicEase; $global:cpEase.EasingMode = 'EaseOut'

function global:Hide-CP {
  if ($global:cpHiding) { return }
  $global:cpHiding = $true
  $global:cpHold.Stop(); $global:cpStack.Stop()
  # Sofort abmelden, damit die anderen Karten schon nachruecken, waehrend diese ausblendet
  Remove-Item $global:cpFile
  $out = New-Object System.Windows.Media.Animation.DoubleAnimation($global:cpWin.Left, ($global:cpLeft + 40), [TimeSpan]::FromMilliseconds(180))
  $global:cpWin.BeginAnimation([System.Windows.Window]::LeftProperty, $out)
  $global:cpWin.BeginAnimation([System.Windows.Window]::OpacityProperty, (New-Object System.Windows.Media.Animation.DoubleAnimation($global:cpWin.Opacity, 0, [TimeSpan]::FromMilliseconds(180))))
  $global:cpCloseT = New-Object System.Windows.Threading.DispatcherTimer
  $global:cpCloseT.Interval = [TimeSpan]::FromMilliseconds(200)
  $global:cpCloseT.Add_Tick({ $global:cpCloseT.Stop(); $global:cpWin.Close() })
  $global:cpCloseT.Start()
}

$content.FindName('Done').Add_Click({ Write-CPLog "Erledigt geklickt"; Hide-CP })
$content.FindName('Open').Add_Click({
  $h = $global:cpTarget
  Write-CPLog "Klick, Vordergrund: $([CP.Win]::Describe([CP.Win]::GetForegroundWindow()))"
  if ($h -ne [IntPtr]::Zero) {
    if ([CP.Win]::IsIconic($h)) { [CP.Win]::ShowWindow($h, 9) | Out-Null }
    $ok = [CP.Win]::SetForegroundWindow($h)
    # Windows verweigert das manchmal (Vordergrund-Sperre); ein kurzer Alt-Tastendruck hebt sie auf
    if (-not $ok) {
      [CP.Win]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [CP.Win]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
      $ok = [CP.Win]::SetForegroundWindow($h)
    }
    Write-CPLog "SetForegroundWindow: $ok, danach vorne: $([CP.Win]::Describe([CP.Win]::GetForegroundWindow()))"
  } else { Write-CPLog "Klick, aber kein Zielfenster gefunden" }
  Hide-CP
})
$win.Add_MouseEnter({ $global:cpHold.Stop() })
$win.Add_MouseLeave({ if ($global:cpHoldOn) { $global:cpHold.Start() } })

# Ausblenden nach der Anzeigedauer (pausiert, solange die Maus darauf ist); spaetestens nach 5 min hart schliessen.
# Wartet Claude auf eine Antwort, bleibt die Karte laenger stehen als wenn er nur fertig ist.
$cpSecs = if ($Event -eq 'Stop') { Get-CPNum 'CLAUDE_POPUP_SECONDS' 10 } else { Get-CPNum 'CLAUDE_POPUP_WAIT_SECONDS' 30 }
$global:cpHoldOn = $cpSecs -gt 0
$global:cpHold = New-Object System.Windows.Threading.DispatcherTimer
$global:cpHold.Interval = [TimeSpan]::FromSeconds([math]::Max(1, $cpSecs))
$global:cpHold.Add_Tick({ Write-CPLog "Anzeigedauer abgelaufen, ausgeblendet"; Hide-CP })
$global:cpKill = New-Object System.Windows.Threading.DispatcherTimer
$global:cpKill.Interval = [TimeSpan]::FromMinutes(5)
$global:cpKill.Add_Tick({ $global:cpKill.Stop(); $global:cpWin.Close() })

# Stapel regelmaessig pruefen: an den eigenen Platz gleiten, aeltere Karten etwas blasser, bei Bedarf weichen
$global:cpStack = New-Object System.Windows.Threading.DispatcherTimer
$global:cpStack.Interval = [TimeSpan]::FromMilliseconds(200)
$global:cpStack.Add_Tick({
  $slot = Get-CPSlot
  if (-not $slot) {
    # Erst richtig anzeigen, dann ggf. weichen, sonst blitzt eine Karte nur kurz auf.
    if (([DateTime]::UtcNow - $global:cpShown).TotalMilliseconds -lt 2000) { return }
    Write-CPLog "Karte weicht (neuere Karte derselben Session oder zu viele Karten)"; Hide-CP; return
  }
  if ([math]::Abs($slot[0] - $global:cpTop) -gt 0.5) {
    $global:cpTop = $slot[0]
    $move = New-Object System.Windows.Media.Animation.DoubleAnimation($global:cpWin.Top, $slot[0], [TimeSpan]::FromMilliseconds(280))
    $move.EasingFunction = $global:cpEase
    $global:cpWin.BeginAnimation([System.Windows.Window]::TopProperty, $move)
  }
  if ($slot[1] -ne $global:cpPlace) {
    $global:cpPlace = $slot[1]
    $dim = New-Object System.Windows.Media.Animation.DoubleAnimation($global:cpContent.Opacity, (1 - 0.08 * $slot[1]), [TimeSpan]::FromMilliseconds(280))
    $global:cpContent.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $dim)
  }
})

$win.Add_Loaded({
  $global:cpShown = [DateTime]::UtcNow
  Write-CPLog "Angezeigt bei links $([math]::Round($global:cpLeft)) oben $([math]::Round($global:cpTop)), Platz $($global:cpSlotIdx), $(@(Get-CPCards).Count) Karten offen, Anzeigedauer $($global:cpHold.Interval.TotalSeconds)s"
  $slide = New-Object System.Windows.Media.Animation.DoubleAnimation(($global:cpLeft + 40), $global:cpLeft, [TimeSpan]::FromMilliseconds(320))
  $slide.EasingFunction = $global:cpEase
  $global:cpWin.BeginAnimation([System.Windows.Window]::LeftProperty, $slide)
  $global:cpWin.BeginAnimation([System.Windows.Window]::OpacityProperty, (New-Object System.Windows.Media.Animation.DoubleAnimation(0, 1, [TimeSpan]::FromMilliseconds(220))))
  if ($global:cpHoldOn) { $global:cpHold.Start() }
  $global:cpKill.Start(); $global:cpStack.Start()
})
if ($Test) { Write-Host "Popup wird angezeigt. Protokoll: $($global:cpLog)" }
$win.ShowDialog() | Out-Null
Remove-Item $global:cpFile
Write-CPLog "Popup beendet"
if ($Test) {
  Write-Host ""
  Write-Host "--- letzte Protokollzeilen ($($global:cpLog)) ---"
  Get-Content -LiteralPath $global:cpLog -Tail 25 | ForEach-Object { Write-Host $_ }
}
