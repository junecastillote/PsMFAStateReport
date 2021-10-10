Function New-SummaryStackedBarChart {
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
        $IsReversed
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Windows.Forms.DataVisualization

    #Create Chart
    $Chart = [System.Windows.Forms.DataVisualization.Charting.Chart]::new()
    # $Chart.AutoSize = $true
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
    # X Axis
    $ChartArea.AxisX.IsLabelAutoFit = $true
    $ChartArea.AxisX.LabelStyle.Font = [System.Drawing.Font]::new('Segoe UI', '10')
    $ChartArea.AxisX.LabelStyle.ForeColor = 'DimGray'
    $ChartArea.AxisX.LineColor = 'Silver'
    $ChartArea.AxisX.MajorGrid.Enabled = $false
    $ChartArea.AxisX.IntervalAutoMode = 'VariableCount'
    $ChartArea.AxisX.MaximumAutoSize = 50
    $ChartArea.AxisX.LabelAutoFitStyle = 'DecreaseFont, WordWrap'
    # $ChartArea.AxisX.LabelAutoFitStyle = 'DecreaseFont'
    $ChartArea.AxisX.IsReversed = $IsReversed

    # Y Axis
    $ChartArea.AxisY.Enabled = [System.Windows.Forms.DataVisualization.Charting.AxisEnabled]::False
    $ChartArea.AxisY.IsLabelAutoFit = $true
    $ChartArea.AxisY.LabelStyle.Font = [System.Drawing.Font]::new('Segoe UI', '10')
    $ChartArea.AxisY.LabelStyle.ForeColor = 'DimGray'
    $ChartArea.AxisY.LineColor = 'Silver'
    $ChartArea.AxisY.MajorGrid.LineColor = 'LightGray'
    $ChartArea.AxisY.MajorGrid.LineWidth = 2

    # Add Chart Area to Chart
    $Chart.ChartAreas.Add($ChartArea)

    $dataCollection = [System.Collections.ArrayList]::new()
    $null = $dataCollection.AddRange($InputObject)
    $itemIndex = 0
    foreach ($item in $dataCollection) {
        $data = $item | ConvertTo-Hashtable -key Name -value Value
        $SeriesName = "Series$($itemIndex)"
        $Chart.Series.Add([System.Windows.Forms.DataVisualization.Charting.Series]@{
                ChartType        = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::StackedBar100
                LabelBackColor   = '#5c5858'
                LabelForeColor   = '#e9e1e1'
                LabelBorderColor = 'White'
                Font             = [System.Drawing.Font]::new('Segoe UI', '10')
                Name             = $SeriesName
            })
        $Chart.Series[$SeriesName].Points.DataBindXY($data.Keys, $data.Values)
        $Chart.Series[$SeriesName].Label = "#VALY"
        $chart.Series[$SeriesName].LegendText = ($item[0].Type)
        $itemIndex++
    }

    if ($RandomColors) {
        $Palette = @(Get-ColorPalette | Sort-Object { Get-Random })
        for ($i = 0; $i -le ($Chart.Series.Count - 1); $i++) {
            $Chart.Series[$i].Color = $Palette[$i]
        }
    }

    $Chart.Legends.Add(
        [System.Windows.Forms.DataVisualization.Charting.Legend]@{
            IsEquallySpacedItems = $True
            BackColor            = [System.Drawing.Color]::White
            Alignment            = 'Near'
            LegendItemOrder      = $(
                if ($IsReversed) {
                    'Auto'
                }
                else {
                    'SameAsSeriesOrder'
                }
            )
            Docking              = 'Bottom'
            Font                 = [System.Drawing.Font]::new('Segoe UI', 10)
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