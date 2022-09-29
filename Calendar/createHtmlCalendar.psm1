function CreateOneMonth ([string]$fnStartDay, [string]$fnEndDay, $fnHighlight = "False", $fnCreateHTMLOneMount = "False", $fnOutFilePath) {
    <#
    .Synopsis
        Function for creating one month.
    .Parameter fnStartDay
        Defines the beginning of the calendar month calculation , and is also the beginning of the color range (if the $highlight = True parameter)
    .Parameter fnEndDay
        Specifies the end of the color selection range (if the $highlight = True parameter).
    .Parameter fnHighlight
        Select the range from $fnStartDay to $fnEndDay in color. By default, False.
    .Parameter createHTMLOneMount
        Parameter for creating independent output to a file or to the console, one month. By default, False.
    .Parameter fnOutFilePath
        Output to file, by default output to the console. By default, False.
    .Example
        CreateOneMonth -fnStartDay 15.10.2020 -fnEndDay 25.10.2020 -fnHighlight "True"
        CreateOneMonth -fnStartDay 15.10.2020 -fnEndDay 25.10.2020 -fnHighlight "True" -createHTMLOneMount "True" -fnOutFilePath C:\Script\oneMount.html
    #>

    $today = get-date $fnStartDay
    $todayEnd = get-date $fnEndDay
    $highlight = $fnHighlight
    $OutFilePath = $fnOutFilePath

    #The range of dates that we will highlight in color.
    if ( $fnHighlight -eq "True"){
        $todayRange = $today.Day..$todayEnd.Day
    }

    $mountAndYear = Get-Date $today -UFormat "%m.%Y "
    [string]$m = $mountAndYear
    $lastDay = [DateTime]::DaysInMonth($today.Year, $today.Month)
    $firstDate = [DateTime]::new($today.Year, $today.Month, 1)
    $lastDate  = [DateTime]::new($today.Year, $today.Month, $lastDay)
    [int]$startDay = Get-Date $firstDate -Format "%d"
    [int]$endDay = $lastDay

    #Output the value, the name "Month Year" in English.
    switch ($today.Month) {
        1 { $mountYear = ("January "+ $today.Year) }
        2 { $mountYear = ("February "+ $today.Year) }
        3 { $mountYear = ("Mart "+ $today.Year) }
        4 { $mountYear = ("April "+ $today.Year) }
        5 { $mountYear = ("May "+ $today.Year) }
        6 { $mountYear = ("June "+ $today.Year) }
        7 { $mountYear = ("July "+ $today.Year) }
        8 { $mountYear = ("August "+ $today.Year) }
        9 { $mountYear = ("September "+ $today.Year) }
        10 { $mountYear = ("October "+ $today.Year) }
        11 { $mountYear = ("November "+ $today.Year) }
        12 { $mountYear = ("December "+ $today.Year) }
    }

    $WeekOfMounthCount = 1
    #Collecting an array of one month.
    $arrCalendar = @()
    for ( $i = $startDay; $i -le $endDay; $i++ ){
        
        #Date.
        [string]$d = $i
        $date = "$d.$m" 
        #Day (Day in numeric format).
        $day = (Get-Date $date -Format "%d")
        #Mount (Month in numeric format).
        $mount = (Get-Date $date -Format "%M")
        #Year (Year in numeric format).
        $year = (Get-Date $date -Format "yyyy")
        #dayOfWeek (Day of the week).
        $dayOfWeek = (get-date $date).DayOfWeek
        #dayOfWeekNum (Day of the week in numeric format).
        $dayOfWeekNumFind = (Get-Date $date -UFormat "%w")
            if ($DayOfWeekNumFind -eq "0"){
                $dayOfWeekNum = "7"
            }else { $dayOfWeekNum = $dayOfWeekNumFind}

        #WeekOfMounthNum (Number of the week in the month).
        if ($dayOfWeekNum -eq 7){
            $WeekOfMounthCount ++
        }
        else{
            $WeekOfMounthNum = $WeekOfMounthCount
        }
        #Adding it to the array.
        $objectCalendar = New-Object System.Object
        $objectCalendar | Add-Member -Type NoteProperty -Name Date -Value $date
        $objectCalendar | Add-Member -type NoteProperty -Name Day -Value $day
        $objectCalendar | Add-Member -type NoteProperty -Name Mount -Value $mount
        $objectCalendar | Add-Member -type NoteProperty -Name Year -Value $year
        $objectCalendar | Add-Member -type NoteProperty -Name DayOfWeek -Value $dayOfWeek
        $objectCalendar | Add-Member -type NoteProperty -Name DayOfWeekNum -Value $dayofWeekNum
        $objectCalendar | Add-Member -type NoteProperty -Name WeekOfMounthNum -Value $WeekOfMounthNum
        $arrCalendar += $objectCalendar
    }
    #The number of weeks in a month.
    $totalWeekOfMounth = $arrCalendar | Select-Object WeekOfMounthNum -Unique
    #Creating a table in HTML.
    $arrHtmlWeek = @()
    foreach ( $iWeek in $totalWeekOfMounth.WeekOfMounthNum ){

        $fillWeekList = $arrCalendar | Where-Object { $_.WeekOfMounthNum -like "$iWeek"}
        $arrFillWeek = @()
        
        for( $iDayWeek = 1; $iDayWeek -lt 8; $iDayWeek++){
            
            $swDay = $fillWeekList | Where-Object { $_.DayOfWeekNum -eq $iDayWeek}
            $swtDay = $swDay.Day
            $swtDayWeek = $swDay.DayOfWeek
            $swtDayWeekNum = $swDay.DayOfWeekNum
            $swtWeekOfMounthNum = $swDay.WeekOfMounthNum
            
            if ($highlight -eq "True"){
                if($todayRange -eq $swtDay){
                    $color = "<span style='font-size:10.0pt;color:#0051F9'>"
                }
                else { $color = "<span style='font-size:10.0pt;color:#999999'>"}
            }
            else { $color = "<span style='font-size:10.0pt;color:#999999'>"}

            switch ($swtDayWeekNum) {
                1 { $swtBuildDay = "<td width=20 height=10 valign=top><p align='center'>$color $swtDay </span></p></td> `n"}
                2 { $swtBuildDay = "<td width=20 height=10 valign=top><p align='center'>$color $swtDay </span></p></td> `n"}
                3 { $swtBuildDay = "<td width=20 height=10 valign=top><p align='center'>$color $swtDay </span></p></td> `n"}
                4 { $swtBuildDay = "<td width=20 height=10 valign=top><p align='center'>$color $swtDay </span></p></td> `n"}
                5 { $swtBuildDay = "<td width=20 height=10 valign=top><p align='center'>$color $swtDay </span></p></td> `n"}
                6 { $swtBuildDay = "<td width=20 height=10 valign=top><p align='center'>$color $swtDay </span></p></td> `n"}
                7 { $swtBuildDay = "<td width=20 height=10 valign=top><p align='center'>$color $swtDay </span></p></td> `n"}
                Default { $swtBuildDay = "<td width=20 height=10 valign=top><p align='center'>&nbsp;<o:p></o:p></p></td>"}
            }
            $obFillWeek = New-Object System.Object
            $obFillWeek | Add-Member -Type NoteProperty -Name Week -Value $swtBuildDay
            $arrFillWeek += $obFillWeek

        }

        $obHtmlWeek = New-Object System.Object
        $obHtmlWeek | Add-Member -Type NoteProperty -Name HTMLWeek -Value $arrFillWeek.Week
        $arrHtmlWeek += $obHtmlWeek

    }

    $mountParam = "<td width=140 height=12 colspan=7 valign=top><p align='center'><b><span style='font-size:12.0pt;color:#31527B'> $mountYear </span></b></p></td>"
    $HTMLWeek1 = $arrHtmlWeek[0].HTMLWeek
    $HTMLWeek2 = $arrHtmlWeek[1].HTMLWeek
    $HTMLWeek3 = $arrHtmlWeek[2].HTMLWeek
    $HTMLWeek4 = $arrHtmlWeek[3].HTMLWeek
    $HTMLWeek5 = $arrHtmlWeek[4].HTMLWeek
    $HTMLWeek6 = $arrHtmlWeek[5].HTMLWeek

$createHTMLMount = ("
<td valign=top>
<div>
<style>
.mytable2{
    width: 180px;
    border: 0px;
    margin: auto;
    border-collapse: collapse;
    border-spacing: 0px 0px;
    vertical-align: top;
}
td{
    line-height: 0px;
    padding: 0px;
    vertical-align: top;
    height: 15px;
}
</style>
<table border=0 cellspacing=0 cellpadding=0 align=center valign=top height=92 class=mytable2>
<tbody>
<tr>
    "+ $mountParam +"
    <td width=40 height=12></td>
</tr>
<tr>
    <td width=20 height=10 valign=top><p align='center'><span style='font-size:10.0pt;color:#31527B'>Mo</span></p></td>
    <td width=20 height=10 valign=top><p align='center'><span style='font-size:10.0pt;color:#31527B'>Tu</span></p></td>
    <td width=20 height=10 valign=top><p align='center'><span style='font-size:10.0pt;color:#31527B'>We</span></p></td>
    <td width=20 height=10 valign=top><p align='center'><span style='font-size:10.0pt;color:#31527B'>Th</span></p></td>
    <td width=20 height=10 valign=top><p align='center'><span style='font-size:10.0pt;color:#31527B'>Fr</span></p></td>
    <td width=20 height=10 valign=top><p align='center'><span style='font-size:10.0pt;color:#FF0000'>Sa</span></p></td>
    <td width=20 height=10 valign=top><p align='center'><span style='font-size:10.0pt;color:#FF0000'>Su</span></p></td>
    <td width=40 height=10 valign=top></td>
</tr>
<tr>
    "+ $HTMLWeek1 +"
</tr>
<tr>
    "+ $HTMLWeek2 +"
</tr>
<tr>
    "+ $HTMLWeek3 +"
</tr>
<tr>
    "+ $HTMLWeek4 +"
</tr>
<tr>
    "+ $HTMLWeek5 +"
</tr>
<tr>
    "+ $HTMLWeek6 +"
</tr>
<tr>
    <td width=140 height=10 valign=top colspan=7></td>
    <td width=40 height=10 valign=top></td>
</tr>
</tbody>
</table>
</div>
</td>
")

    if ( $fnCreateHTMLOneMount -eq "True"){

        $buildHTMLOneMount = ("
        <html>
        <head>
        <style>
        </style>
        </head>
        <body>
        <div>
        $createHTMLMount
        </div>
        </body>
        </html>
        ")
        if ($OutFilePath){
            $buildHTMLOneMount | Out-File $OutFilePath
        }
        else{
            return $buildHTMLOneMount
        }
    }
    else {
        return $createHTMLMount
    }
}

function CreateBigCalendar ( $beginDay , $finishDay , $fnResHighlight = "False", $OutFilePathForAllMount, $message )  {

    <#
    .Synopsis
        This function creates a calendar of one month or more and adds a signature at the end of the calendar.
    .Parameter beginDay
        Defines the beginning of the calendar month calculation , and is also the beginning of the color range (if the $fnResHighlight = True parameter)
    .Parameter finishDay
        Defines the end of the calendar month calculation, and is also the end of the range color selection (if the $fnResHighlightt = True parameter).
    .Parameter fnResHighlight
        Select the range from $beginDay to $finishDay in color. By default, False.   
    .Parameter OutFilePathForAllMount
        Parameter for output to a file.
    .Parameter message
        Add text under the created calendar
    .Example
        resultCreateCalendarMonths -beginDay 20.03.2021 -finishDay 11.04.2021 -fnResHighlight "True"
        resultCreateCalendarMonths -beginDay 20.03.2021 -finishDay 11.04.2021 -fnResHighlight "True" -message $msg
        resultCreateCalendarMonths -beginDay 01.01.2021 -finishDay 20.12.2021 -fnResHighlight "False" -OutFilePathForAllMount "C:\msi\otpusk2.html" -message $msg
    #>
 
    $fnResStartDay = get-date $beginDay
    $fnResEndDay = get-date $finishDay
    
    #We count the number of incoming months in the range from $beginDay to $finishDay.
    $sta = [DateTime]::new($fnResStartDay.Year, $fnResStartDay.Month, 1)
    [string]$fin = [DateTime]::new($fnResEndDay.Year, $fnResEndDay.Month, 1)
    $fnCount = @()
    $i=0
    Do {
        [string]$d = $sta.AddMonths($i)
        $fnCount += $d
        $i++
    }
    While ($d -notmatch $fin)
    
    #Calculation of the range from $fnResStartDay to $fnResEndDay containing the start and end date in the month, for generating tables in HTML.
    $myArray = @()
    if ($fnCount.Count -eq 1){
        $myObject = New-Object System.Object
        $myObject | Add-Member -Type NoteProperty -Name StartDay -Value $fnResStartDay
        $myObject | Add-Member -Type NoteProperty -Name EndDay -Value $fnResEndDay
        $myArray += $myObject
    }
    elseif ($fnCount.Count -eq 2) {
        for ($i=1; $i -le 2; $i++){
            $myObject = New-Object System.Object
            if ($i -eq 1){
                $lastDay = [DateTime]::DaysInMonth($fnResStartDay.Year, $fnResStartDay.Month)
                $lastDate  = [DateTime]::new($fnResStartDay.Year, $fnResStartDay.Month, $lastDay)
                $myObject | Add-Member -Type NoteProperty -Name StartDay -Value $fnResStartDay
                $myObject | Add-Member -Type NoteProperty -Name EndDay -Value $lastDate
            }
            elseif($i -eq 2){
                $firstDate = [DateTime]::new($fnResEndDay.Year, $fnResEndDay.Month, 1)
                $myObject | Add-Member -Type NoteProperty -Name StartDay -Value $firstDate
                $myObject | Add-Member -Type NoteProperty -Name EndDay -Value $fnResEndDay
            }
            $myArray += $myObject
        }
    }
    else{
        for ($i=1; $i -le $fnCount.Count; $i++){
            $myObject = New-Object System.Object
            if ($i -eq 1){
                $lastDay = [DateTime]::DaysInMonth($fnResStartDay.Year, $fnResStartDay.Month)
                $lastDate  = [DateTime]::new($fnResStartDay.Year, $fnResStartDay.Month, $lastDay)
                $myObject | Add-Member -Type NoteProperty -Name StartDay -Value $fnResStartDay
                $myObject | Add-Member -Type NoteProperty -Name EndDay -Value $lastDate
            }
            elseif($i -eq $fnCount.Count){
                $firstDate = [DateTime]::new($fnResEndDay.Year, $fnResEndDay.Month, 1)
                $myObject | Add-Member -Type NoteProperty -Name StartDay -Value $firstDate
                $myObject | Add-Member -Type NoteProperty -Name EndDay -Value $fnResEndDay
            }
            else{
                $calculationMonth = $fnResStartDay.AddMonths($i-1)
                $firstDate = [DateTime]::new($calculationMonth.Year, $calculationMonth.Month, 1)
                $lastDay = [DateTime]::DaysInMonth($calculationMonth.Year, $calculationMonth.Month)
                $lastDate  = [DateTime]::new($calculationMonth.Year, $calculationMonth.Month, $lastDay)
                $myObject | Add-Member -Type NoteProperty -Name StartDay -Value $firstDate
                $myObject | Add-Member -Type NoteProperty -Name EndDay -Value $lastDate
            }
            $myArray += $myObject
        }
    }

    #Creating a common table by adding one table (for each month).
    function buildTableHTML {
        #The number of months in the General table specified in the $BatchBy = 3 parameter (the number 3 indicates how many tables (myasyats) will be on one line).
        $BatchBy = 3
        for ( $i=0; $i -lt $myArray.Count; $i += $BatchBy ){
        
            $1 = $myArray[$i..($i+$BatchBy-1)]
            $writeInTableHTML1 = ("
            <tbody>
            <tr>
            ")
            $writeInTableHTML1

            foreach ( $2 in $1 ){
                $pam1 = get-date $2.StartDay -Format "dd.MM.yyyy"
                $pam2 = get-date $2.EndDay -Format "dd.MM.yyyy"
                CreateOneMonth -fnStartDay $pam1 -fnEndDay $pam2 -fnHighlight $fnResHighlight
            }

            $writeInTableHTML2 = ("
            </tr>
            </tbody>
            ")
            $writeInTableHTML2
        }
    }
    #Add message.
    function resultP ($message) {
        $textMsg = $message -split "`n"
        for ($t = 0; $t -lt $textMsg.Count; $t++) {
            $textMessage = $textMsg[$t] 
            $createP = ("<p align='left'>$textMessage</p>")
            $createP
        }
    }

    $createHTMLmount2 = buildTableHTML
    $createHTMLmsg = resultP -message $message

    $createHTMLBigMount = ("
    <!DOCTYPE html>
    <html>
    <head>
    <style>
    .mytable1{
        border: 0px;
        margin: auto;
        border-collapse: collapse;
        border-spacing: 0px 0px;
    }
    </style>
    </head>
    <body>
    <div>
    <table border=0 cellspacing=0 cellpadding=0 align=center frame=void height=100% class=mytable1>
    $createHTMLmount2
    </table>
    $createHTMLmsg
    </div>
    </body>
    </html>
    ")

    if ($OutFilePathForAllMount){
        $createHTMLBigMount | Out-File $OutFilePathForAllMount
    }
    else {
        return $createHTMLBigMount
    }
}
