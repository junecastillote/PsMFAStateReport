Function New-SummaryPieChart {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        $InputObject,

        [Parameter()]
        [string]
        $SaveToFile,

        [parameter()]
        [int]
        $Width = 450,

        [parameter()]
        [int]
        $Height = 400,

        [parameter()]
        [string]
        $FooterText,

        [parameter()]
        [switch]
        $RandomColors,

        [parameter()]
        [switch]
        $IsReversed,

        [parameter()]
        [string[]]
        $ColorSequence
    )

    if (($ColorSequence.Count) -and (($ColorSequence.Count) -lt ($InputObject.Count))) {
        Write-Warning "The number of colors you specified [$($ColorSequence.Count)] is less than the number of datapoints [$($InputObject.Count))] to add in the chart. Either add more colors to match the datapoints or do not use the ColorSequence parameter to use the default colors."
        return $null
    }

    if ($ColorSequence -and $RandomColors) {
        Write-Warning "You selected both ColorSequence and RandomColors. You should only use one color related parameter. Otherwise, ColorSequence will take effect and RandomColors will be ignored."
        $RandomColors = $false
    }

    # $Palette = @(Get-ColorPalette | Sort-Object { Get-Random })

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Windows.Forms.DataVisualization

    #Create Chart
    $Chart = [System.Windows.Forms.DataVisualization.Charting.Chart]::new()
    $Chart.Width = $Width
    $Chart.Height = $Height
    $Chart.BackColor = 'White'

    if ($FooterText) {
        #Create Footer
        $footerTitle = [System.Windows.Forms.DataVisualization.Charting.Title]@{
            Font      = [System.Drawing.Font]::new('Segoe UI', '10', 'Italic', 'Point')
            ForeColor = 'DimGray'
            Docking   = 'Bottom'
            Alignment = 'BottomLeft'
            Text      = $FooterText
        }
        $Chart.Titles.Add($footerTitle)
    }
    #Create Chart Area
    $ChartArea = [System.Windows.Forms.DataVisualization.Charting.ChartArea]::new()
    $ChartArea.BorderColor = 'Silver'
    $ChartArea.BackHatchStyle = 'LightDownwardDiagonal'
    $ChartArea.BackColor = 'WhiteSmoke'

    $Chart.ChartAreas.Add($ChartArea)

    $Chart.Series.Add([System.Windows.Forms.DataVisualization.Charting.Series]@{
            ChartType        = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Doughnut
            LabelBackColor   = '#5c5858'
            LabelForeColor   = '#e9e1e1'
            LabelBorderColor = 'White'
            Font             = [System.Drawing.Font]::new('Segoe UI', '10')
        })

    $data = $InputObject | ConvertTo-Hashtable -key Name -value Value
    $Chart.Series['Series1'].Points.DataBindXY($data.Keys, $data.Values)
    $Chart.Series['Series1'].Label = "#VALY"
    $chart.Series["Series1"].LegendText = "#VALX"
    $Chart.Series['Series1']['PieDrawingStyle'] = 'Concave'

    if ($ColorSequence) {
        for ($i = 0; $i -le ($Chart.Series['Series1'].Points.Count - 1); $i++) {
            $Chart.Series['Series1'].Points[$i].Color = $ColorSequence[$i]
        }
    }

    if ($RandomColors) {
        $Palette = @(Get-ColorPalette | Sort-Object { Get-Random })
        for ($i = 0; $i -le ($Chart.Series['Series1'].Points.Count - 1); $i++) {
            $Chart.Series['Series1'].Points[$i].Color = $Palette[$i]
        }
    }

    $Chart.Legends.Add(
        [System.Windows.Forms.DataVisualization.Charting.Legend]@{
            IsEquallySpacedItems = $True
            BackColor            = [System.Drawing.Color]::White
            Alignment            = 'Center'
            LegendItemOrder      = 'SameAsSeriesOrder'
            Docking              = 'Bottom'
            Font                 = [System.Drawing.Font]::new('Segoe UI', '10')
        }
    )

    if (!$SaveToFile) {
        # Show the graph window only
        $Form = [Windows.Forms.Form]@{
            AutoSize        = $true
            FormBorderStyle = 'FixedDialog'
        }
        $Form.controls.add($Chart)
        $Chart.Anchor = 'Bottom, Right, Top, Left'
        $Form.Add_Shown( { $Form.Activate() })
        [void]$Form.ShowDialog()
    }
    else {
        #Save Chart to PNG file
        $Extension = $SaveToFile -replace '.*\.(.*)', '$1'
        $Chart.SaveImage($SaveToFile, $Extension)
    }
}