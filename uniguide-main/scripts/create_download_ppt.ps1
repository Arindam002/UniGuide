param(
    [string]$OutputPath,
    [string]$IconPath
)

function RGB-Color([int]$r, [int]$g, [int]$b) { return ($r + (256 * $g) + (65536 * $b)) }
function Add-TextBox {
    param($Slide,[double]$Left,[double]$Top,[double]$Width,[double]$Height,[string]$Text,[int]$FontSize=20,[int]$Color=0,[string]$FontName='Segoe UI',[int]$Bold=0,[int]$Alignment=1,[single]$Transparency=1.0)
    $shape = $Slide.Shapes.AddTextbox(1,$Left,$Top,$Width,$Height)
    $shape.TextFrame.TextRange.Text = $Text
    $shape.TextFrame.TextRange.Font.Name = $FontName
    $shape.TextFrame.TextRange.Font.Size = $FontSize
    $shape.TextFrame.TextRange.Font.Bold = $Bold
    $shape.TextFrame.TextRange.Font.Color.RGB = $Color
    $shape.TextFrame.TextRange.ParagraphFormat.Alignment = $Alignment
    $shape.TextFrame.MarginLeft = 6
    $shape.TextFrame.MarginRight = 6
    $shape.TextFrame.MarginTop = 4
    $shape.TextFrame.MarginBottom = 4
    $shape.Fill.Transparency = $Transparency
    $shape.Line.Visible = 0
    return $shape
}
function Add-Card {
    param($Slide,[double]$Left,[double]$Top,[double]$Width,[double]$Height,[int]$FillColor,[int]$LineColor,[single]$FillTransparency=0.0,[single]$LineTransparency=0.0,[int]$RadiusShape=5)
    $shape = $Slide.Shapes.AddShape($RadiusShape,$Left,$Top,$Width,$Height)
    $shape.Fill.ForeColor.RGB = $FillColor
    $shape.Fill.Transparency = $FillTransparency
    $shape.Line.ForeColor.RGB = $LineColor
    $shape.Line.Transparency = $LineTransparency
    $shape.Line.Weight = 1.25
    return $shape
}
function Add-Circle {
    param($Slide,[double]$Left,[double]$Top,[double]$Size,[int]$FillColor,[single]$Transparency=0.4)
    $shape = $Slide.Shapes.AddShape(9,$Left,$Top,$Size,$Size)
    $shape.Fill.ForeColor.RGB = $FillColor
    $shape.Fill.Transparency = $Transparency
    $shape.Line.Visible = 0
    return $shape
}
function Add-Tag {
    param($Slide,[double]$Left,[double]$Top,[double]$Width,[double]$Height,[string]$Text,[int]$FillColor,[int]$TextColor)
    $tag = Add-Card -Slide $Slide -Left $Left -Top $Top -Width $Width -Height $Height -FillColor $FillColor -LineColor $FillColor
    $tag.Line.Visible = 0
    Add-TextBox -Slide $Slide -Left ($Left+4) -Top ($Top+2) -Width ($Width-8) -Height ($Height-4) -Text $Text -FontSize 12 -Color $TextColor -Bold 1 -Alignment 2 | Out-Null
}
function Add-Arrow {
    param($Slide,[double]$X1,[double]$Y1,[double]$X2,[double]$Y2,[int]$Color)
    $line = $Slide.Shapes.AddLine($X1,$Y1,$X2,$Y2)
    $line.Line.ForeColor.RGB = $Color
    $line.Line.Weight = 2
    $line.Line.EndArrowheadStyle = 3
    return $line
}

$navy = RGB-Color 16 34 64
$blue = RGB-Color 32 90 164
$sky = RGB-Color 110 189 255
$teal = RGB-Color 47 164 176
$gold = RGB-Color 244 178 62
$cream = RGB-Color 247 249 252
$paper = RGB-Color 255 255 255
$ink = RGB-Color 28 39 56
$muted = RGB-Color 98 113 137
$line = RGB-Color 216 226 238
$softBlue = RGB-Color 232 242 255
$softTeal = RGB-Color 228 247 244
$softGold = RGB-Color 255 244 219
$softPink = RGB-Color 255 236 236

if (Test-Path $OutputPath) { Remove-Item -LiteralPath $OutputPath -Force }

$ppt = $null
$presentation = $null

try {
    $ppt = New-Object -ComObject PowerPoint.Application
    $ppt.Visible = -1
    $presentation = $ppt.Presentations.Add()
    $presentation.PageSetup.SlideWidth = 960
    $presentation.PageSetup.SlideHeight = 540

    $slide = $presentation.Slides.Add(1,12)
    $bg=$slide.Shapes.AddShape(1,0,0,960,540); $bg.Fill.ForeColor.RGB=$navy; $bg.Line.Visible=0
    Add-Circle -Slide $slide -Left 660 -Top -60 -Size 260 -FillColor $sky -Transparency 0.78 | Out-Null
    Add-Circle -Slide $slide -Left 760 -Top 180 -Size 180 -FillColor $teal -Transparency 0.78 | Out-Null
    Add-Circle -Slide $slide -Left -70 -Top 320 -Size 220 -FillColor $gold -Transparency 0.82 | Out-Null
    Add-Tag -Slide $slide -Left 58 -Top 42 -Width 135 -Height 28 -Text 'AI Study Assistant' -FillColor $blue -TextColor $paper
    if (Test-Path $IconPath) { $slide.Shapes.AddPicture($IconPath,0,-1,60,88,70,70) | Out-Null }
    Add-TextBox -Slide $slide -Left 145 -Top 82 -Width 520 -Height 60 -Text 'UniGuide' -FontSize 28 -Color $paper -FontName 'Georgia' -Bold 1 | Out-Null
    Add-TextBox -Slide $slide -Left 60 -Top 138 -Width 700 -Height 90 -Text 'A Creative Presentation of the Work Done in the Project' -FontSize 30 -Color $paper -FontName 'Segoe UI Semibold' -Bold 1 | Out-Null
    Add-TextBox -Slide $slide -Left 60 -Top 220 -Width 650 -Height 52 -Text 'Flutter frontend + Flask backend + RAG pipeline for academic content discovery, retrieval, and AI-assisted exam preparation.' -FontSize 17 -Color $softBlue | Out-Null
    Add-Card -Slide $slide -Left 58 -Top 358 -Width 250 -Height 118 -FillColor $paper -LineColor $paper -FillTransparency 0.06 -LineTransparency 0.75 | Out-Null
    Add-TextBox -Slide $slide -Left 74 -Top 376 -Width 220 -Height 84 -Text "Student Details`r`nName: [Your Name]`r`nRoll No: [Your Roll Number]" -FontSize 18 -Color $paper -Bold 1 | Out-Null
    Add-Card -Slide $slide -Left 330 -Top 358 -Width 250 -Height 118 -FillColor $paper -LineColor $paper -FillTransparency 0.06 -LineTransparency 0.75 | Out-Null
    Add-TextBox -Slide $slide -Left 346 -Top 376 -Width 220 -Height 84 -Text "Institute / Department`r`nBranch: Computer Science / Relevant Branch`r`nSession: [Academic Year]" -FontSize 18 -Color $paper -Bold 1 | Out-Null
    Add-Card -Slide $slide -Left 602 -Top 358 -Width 300 -Height 118 -FillColor $paper -LineColor $paper -FillTransparency 0.06 -LineTransparency 0.75 | Out-Null
    Add-TextBox -Slide $slide -Left 620 -Top 376 -Width 264 -Height 84 -Text "Mentor`r`nName: [Mentor Name]`r`nRole: Project Guide / Supervisor" -FontSize 18 -Color $paper -Bold 1 | Out-Null

    $slide = $presentation.Slides.Add(2,12); $bg=$slide.Shapes.AddShape(1,0,0,960,540); $bg.Fill.ForeColor.RGB=$cream; $bg.Line.Visible=0
    Add-Tag -Slide $slide -Left 52 -Top 30 -Width 110 -Height 26 -Text '01 Introduction' -FillColor $softBlue -TextColor $blue
    Add-TextBox -Slide $slide -Left 52 -Top 64 -Width 380 -Height 42 -Text 'Introduction' -FontSize 26 -Color $ink -FontName 'Georgia' -Bold 1 | Out-Null
    Add-Card -Slide $slide -Left 52 -Top 122 -Width 390 -Height 320 -FillColor $paper -LineColor $line | Out-Null
    Add-TextBox -Slide $slide -Left 72 -Top 145 -Width 340 -Height 34 -Text 'Project Overview' -FontSize 20 -Color $ink -Bold 1 | Out-Null
    Add-TextBox -Slide $slide -Left 72 -Top 190 -Width 338 -Height 220 -Text "UniGuide is an AI-powered academic companion built for university students.`r`n`r`nIt brings together structured study resources such as books, notes, and previous year questions with a conversational chatbot that answers queries from the available materials.`r`n`r`nThe system is designed to reduce the time students spend searching across folders, PDFs, and scattered notes." -FontSize 18 -Color $muted | Out-Null
    Add-Card -Slide $slide -Left 470 -Top 122 -Width 438 -Height 150 -FillColor $paper -LineColor $line | Out-Null
    Add-TextBox -Slide $slide -Left 492 -Top 144 -Width 390 -Height 30 -Text 'Key Idea' -FontSize 19 -Color $ink -Bold 1 | Out-Null
    Add-TextBox -Slide $slide -Left 492 -Top 184 -Width 390 -Height 70 -Text 'Instead of manually opening many PDFs, students can browse content by branch, semester, and subject, or ask the chatbot a natural language question and receive context-grounded answers.' -FontSize 17 -Color $muted | Out-Null
    Add-Card -Slide $slide -Left 470 -Top 292 -Width 438 -Height 150 -FillColor $navy -LineColor $navy | Out-Null
    Add-TextBox -Slide $slide -Left 492 -Top 314 -Width 390 -Height 28 -Text 'Core Modules' -FontSize 19 -Color $paper -Bold 1 | Out-Null
    Add-TextBox -Slide $slide -Left 492 -Top 352 -Width 390 -Height 72 -Text 'Frontend: Flutter cross-platform UI`r`nBackend: Flask APIs for content and chat`r`nAI Layer: RAG with embeddings, FAISS, reranking, and Groq generation' -FontSize 17 -Color $softBlue | Out-Null
    Add-Tag -Slide $slide -Left 52 -Top 465 -Width 120 -Height 26 -Text 'Three resource modes' -FillColor $softTeal -TextColor $teal
    Add-Tag -Slide $slide -Left 182 -Top 465 -Width 82 -Height 26 -Text 'Books' -FillColor $softBlue -TextColor $blue
    Add-Tag -Slide $slide -Left 274 -Top 465 -Width 82 -Height 26 -Text 'PYQs' -FillColor $softGold -TextColor $gold
    Add-Tag -Slide $slide -Left 366 -Top 465 -Width 82 -Height 26 -Text 'Notes' -FillColor $softPink -TextColor (RGB-Color 181 64 64)

    $slide = $presentation.Slides.Add(3,12); $bg=$slide.Shapes.AddShape(1,0,0,960,540); $bg.Fill.ForeColor.RGB=$navy; $bg.Line.Visible=0
    Add-Circle -Slide $slide -Left 720 -Top -30 -Size 210 -FillColor $teal -Transparency 0.83 | Out-Null
    Add-Circle -Slide $slide -Left 760 -Top 320 -Size 130 -FillColor $gold -Transparency 0.82 | Out-Null
    Add-Tag -Slide $slide -Left 52 -Top 30 -Width 160 -Height 26 -Text '02 Problem Statement' -FillColor $blue -TextColor $paper
    Add-TextBox -Slide $slide -Left 52 -Top 64 -Width 420 -Height 42 -Text 'Problem Statement' -FontSize 26 -Color $paper -FontName 'Georgia' -Bold 1 | Out-Null
    Add-Card -Slide $slide -Left 52 -Top 126 -Width 388 -Height 334 -FillColor $paper -LineColor $paper -FillTransparency 0.06 -LineTransparency 0.8 | Out-Null
    Add-TextBox -Slide $slide -Left 74 -Top 148 -Width 340 -Height 30 -Text 'Challenges Faced by Students' -FontSize 20 -Color $paper -Bold 1 | Out-Null
    Add-TextBox -Slide $slide -Left 74 -Top 192 -Width 332 -Height 240 -Text "- Academic PDFs are scattered across folders and devices.`r`n- Finding the correct book or PYQ for a subject takes time.`r`n- Students often need concise exam-ready answers, not only raw documents.`r`n- Manual searching inside PDFs is slow and discourages quick revision.`r`n- Existing systems usually separate file browsing and intelligent query answering." -FontSize 18 -Color $softBlue | Out-Null
    Add-Card -Slide $slide -Left 470 -Top 126 -Width 402 -Height 334 -FillColor $paper -LineColor $paper -FillTransparency 0.06 -LineTransparency 0.8 | Out-Null
    Add-TextBox -Slide $slide -Left 492 -Top 148 -Width 350 -Height 30 -Text 'Design Objectives' -FontSize 20 -Color $paper -Bold 1 | Out-Null
    Add-TextBox -Slide $slide -Left 492 -Top 192 -Width 346 -Height 240 -Text "- Provide one place to browse books, notes, and PYQs.`r`n- Support branch -> semester -> subject navigation.`r`n- Answer student questions using only available study material.`r`n- Improve revision speed through retrieval and exam-focused response generation.`r`n- Build a foundation that can scale to more branches and larger academic datasets." -FontSize 18 -Color $softBlue | Out-Null
    Add-Tag -Slide $slide -Left 52 -Top 476 -Width 332 -Height 28 -Text 'Target outcome: a single academic workspace for resource discovery + AI help' -FillColor $gold -TextColor $ink

    $slide = $presentation.Slides.Add(4,12); $bg=$slide.Shapes.AddShape(1,0,0,960,540); $bg.Fill.ForeColor.RGB=$cream; $bg.Line.Visible=0
    Add-Tag -Slide $slide -Left 52 -Top 30 -Width 160 -Height 26 -Text '03 Methodology' -FillColor $softBlue -TextColor $blue
    Add-TextBox -Slide $slide -Left 52 -Top 64 -Width 420 -Height 42 -Text 'Methodology Overview' -FontSize 26 -Color $ink -FontName 'Georgia' -Bold 1 | Out-Null
    $steps = @(@{Title='Collect PDFs'; Color=$softBlue; Text='Books, notes, and PYQs stored in structured folders.'},@{Title='Process Text'; Color=$softTeal; Text='PDF text extraction with OCR fallback for weak scans.'},@{Title='Chunk Content'; Color=$softGold; Text='Long text split into manageable segments for retrieval.'},@{Title='Create Embeddings'; Color=$softPink; Text='SentenceTransformer converts chunks into vectors.'},@{Title='Store and Index'; Color=$softBlue; Text='SQLite keeps metadata and FAISS stores vector index.'},@{Title='Answer Queries'; Color=$softTeal; Text='Retriever + reranker + generator return contextual answers.'})
    $left = 54
    foreach ($step in $steps) {
        Add-Card -Slide $slide -Left $left -Top 176 -Width 132 -Height 152 -FillColor $($step.Color) -LineColor $line | Out-Null
        Add-TextBox -Slide $slide -Left ($left+10) -Top 194 -Width 112 -Height 34 -Text $step.Title -FontSize 16 -Color $ink -Bold 1 -Alignment 2 | Out-Null
        Add-TextBox -Slide $slide -Left ($left+10) -Top 236 -Width 112 -Height 72 -Text $step.Text -FontSize 13 -Color $muted -Alignment 2 | Out-Null
        if ($left -lt 734) { Add-Arrow -Slide $slide -X1 ($left+132) -Y1 252 -X2 ($left+150) -Y2 252 -Color $blue | Out-Null }
        $left += 150
    }
    Add-Card -Slide $slide -Left 86 -Top 376 -Width 790 -Height 100 -FillColor $paper -LineColor $line | Out-Null
    Add-TextBox -Slide $slide -Left 106 -Top 396 -Width 740 -Height 60 -Text 'This workflow converts static academic files into a searchable knowledge base. The retrieval layer keeps answers grounded in study materials, while the generation layer improves readability for revision and exam preparation.' -FontSize 18 -Color $muted -Alignment 2 | Out-Null

    $slide = $presentation.Slides.Add(5,12); $bg=$slide.Shapes.AddShape(1,0,0,960,540); $bg.Fill.ForeColor.RGB=$paper; $bg.Line.Visible=0
    Add-Tag -Slide $slide -Left 52 -Top 30 -Width 180 -Height 26 -Text '03 Methodology / Backend' -FillColor $softTeal -TextColor $teal
    Add-TextBox -Slide $slide -Left 52 -Top 64 -Width 420 -Height 42 -Text 'Backend and Data Pipeline' -FontSize 26 -Color $ink -FontName 'Georgia' -Bold 1 | Out-Null
    Add-Card -Slide $slide -Left 52 -Top 124 -Width 408 -Height 344 -FillColor $navy -LineColor $navy | Out-Null
    Add-TextBox -Slide $slide -Left 72 -Top 146 -Width 360 -Height 30 -Text 'Document Ingestion' -FontSize 20 -Color $paper -Bold 1 | Out-Null
    Add-Card -Slide $slide -Left 74 -Top 192 -Width 160 -Height 58 -FillColor $blue -LineColor $blue | Out-Null
    Add-TextBox -Slide $slide -Left 86 -Top 207 -Width 136 -Height 26 -Text 'Traverse data folder' -FontSize 15 -Color $paper -Bold 1 -Alignment 2 | Out-Null
    Add-Card -Slide $slide -Left 74 -Top 272 -Width 160 -Height 58 -FillColor $teal -LineColor $teal | Out-Null
    Add-TextBox -Slide $slide -Left 86 -Top 287 -Width 136 -Height 26 -Text 'Extract text / OCR' -FontSize 15 -Color $paper -Bold 1 -Alignment 2 | Out-Null
    Add-Card -Slide $slide -Left 74 -Top 352 -Width 160 -Height 58 -FillColor $gold -LineColor $gold | Out-Null
    Add-TextBox -Slide $slide -Left 86 -Top 367 -Width 136 -Height 26 -Text 'Store metadata' -FontSize 15 -Color $ink -Bold 1 -Alignment 2 | Out-Null
    Add-Arrow -Slide $slide -X1 154 -Y1 250 -X2 154 -Y2 270 -Color $paper | Out-Null
    Add-Arrow -Slide $slide -X1 154 -Y1 330 -X2 154 -Y2 350 -Color $paper | Out-Null
    Add-TextBox -Slide $slide -Left 262 -Top 194 -Width 160 -Height 200 -Text "- Auto-detects category, branch, semester, and subject from folder structure.`r`n- Uses file hash to avoid duplicate ingestion.`r`n- Stores document content and page count in SQLite.`r`n- Marks books and PYQs for RAG usage." -FontSize 16 -Color $softBlue | Out-Null
    Add-Card -Slide $slide -Left 494 -Top 124 -Width 394 -Height 344 -FillColor $cream -LineColor $line | Out-Null
    Add-TextBox -Slide $slide -Left 516 -Top 146 -Width 340 -Height 30 -Text 'Service Layer and APIs' -FontSize 20 -Color $ink -Bold 1 | Out-Null
    Add-TextBox -Slide $slide -Left 516 -Top 190 -Width 340 -Height 160 -Text "Flask blueprints expose:`r`n- /items for branches, semesters, subjects, files, view, and download`r`n- /chat for direct and streaming responses`r`n- /health for status checking`r`n- /students for user-related expansion`r`n`r`nSafe path joining is used while serving PDFs to prevent invalid file access." -FontSize 17 -Color $muted | Out-Null
    Add-Tag -Slide $slide -Left 516 -Top 372 -Width 108 -Height 26 -Text 'SQLite' -FillColor $softBlue -TextColor $blue
    Add-Tag -Slide $slide -Left 636 -Top 372 -Width 104 -Height 26 -Text 'FAISS' -FillColor $softTeal -TextColor $teal
    Add-Tag -Slide $slide -Left 752 -Top 372 -Width 112 -Height 26 -Text 'Flask APIs' -FillColor $softGold -TextColor $ink
    Add-TextBox -Slide $slide -Left 516 -Top 418 -Width 340 -Height 40 -Text 'The backend turns raw files into a searchable, API-driven academic knowledge layer.' -FontSize 17 -Color $ink -Bold 1 | Out-Null

    $slide = $presentation.Slides.Add(6,12); $bg=$slide.Shapes.AddShape(1,0,0,960,540); $bg.Fill.ForeColor.RGB=$cream; $bg.Line.Visible=0
    Add-Tag -Slide $slide -Left 52 -Top 30 -Width 182 -Height 26 -Text '03 Methodology / Frontend' -FillColor $softBlue -TextColor $blue
    Add-TextBox -Slide $slide -Left 52 -Top 64 -Width 460 -Height 42 -Text 'Frontend and User Workflow' -FontSize 26 -Color $ink -FontName 'Georgia' -Bold 1 | Out-Null
    Add-Card -Slide $slide -Left 60 -Top 126 -Width 272 -Height 346 -FillColor $navy -LineColor $navy | Out-Null
    Add-TextBox -Slide $slide -Left 86 -Top 146 -Width 220 -Height 28 -Text 'Flutter UI Structure' -FontSize 20 -Color $paper -Bold 1 | Out-Null
    Add-Card -Slide $slide -Left 88 -Top 192 -Width 216 -Height 46 -FillColor $blue -LineColor $blue | Out-Null
    Add-TextBox -Slide $slide -Left 96 -Top 204 -Width 200 -Height 24 -Text 'AdaptiveScaffold dashboard' -FontSize 15 -Color $paper -Bold 1 -Alignment 2 | Out-Null
    Add-Card -Slide $slide -Left 88 -Top 252 -Width 216 -Height 46 -FillColor $teal -LineColor $teal | Out-Null
    Add-TextBox -Slide $slide -Left 96 -Top 264 -Width 200 -Height 24 -Text 'Chat + History management' -FontSize 15 -Color $paper -Bold 1 -Alignment 2 | Out-Null
    Add-Card -Slide $slide -Left 88 -Top 312 -Width 216 -Height 46 -FillColor $gold -LineColor $gold | Out-Null
    Add-TextBox -Slide $slide -Left 96 -Top 324 -Width 200 -Height 24 -Text 'Branch -> Semester -> Subject' -FontSize 15 -Color $ink -Bold 1 -Alignment 2 | Out-Null
    Add-Card -Slide $slide -Left 88 -Top 372 -Width 216 -Height 46 -FillColor $paper -LineColor $line | Out-Null
    Add-TextBox -Slide $slide -Left 96 -Top 384 -Width 200 -Height 24 -Text 'Open / download PDF files' -FontSize 15 -Color $ink -Bold 1 -Alignment 2 | Out-Null
    Add-Card -Slide $slide -Left 362 -Top 126 -Width 540 -Height 346 -FillColor $paper -LineColor $line | Out-Null
    Add-TextBox -Slide $slide -Left 386 -Top 146 -Width 490 -Height 30 -Text 'User Journey' -FontSize 20 -Color $ink -Bold 1 | Out-Null
    Add-TextBox -Slide $slide -Left 388 -Top 188 -Width 476 -Height 210 -Text "1. Student opens the app and chooses Chat, Books, PYQs, or Notes.`r`n2. For file browsing, the app requests branches, semesters, subjects, and file lists from the backend.`r`n3. For AI help, the chat sends the question to /chat and receives answer, sources, and an optional diagram.`r`n4. Shared preferences keep chat sessions and history available across usage.`r`n5. API host changes automatically for web, desktop, and Android emulator environments." -FontSize 17 -Color $muted | Out-Null
    Add-Tag -Slide $slide -Left 388 -Top 420 -Width 118 -Height 26 -Text 'Responsive UI' -FillColor $softBlue -TextColor $blue
    Add-Tag -Slide $slide -Left 518 -Top 420 -Width 124 -Height 26 -Text 'Session history' -FillColor $softTeal -TextColor $teal
    Add-Tag -Slide $slide -Left 654 -Top 420 -Width 130 -Height 26 -Text 'Cross-platform' -FillColor $softGold -TextColor $ink

    $slide = $presentation.Slides.Add(7,12); $bg=$slide.Shapes.AddShape(1,0,0,960,540); $bg.Fill.ForeColor.RGB=$paper; $bg.Line.Visible=0
    Add-Tag -Slide $slide -Left 52 -Top 30 -Width 192 -Height 26 -Text '04 Result and Discussion' -FillColor $softTeal -TextColor $teal
    Add-TextBox -Slide $slide -Left 52 -Top 64 -Width 460 -Height 42 -Text 'Implemented Features' -FontSize 26 -Color $ink -FontName 'Georgia' -Bold 1 | Out-Null
    $cards = @(@{L=52;T=132;W=200;H=112;Fill=$softBlue;Title='3';Body='resource categories integrated'},@{L=272;T=132;W=200;H=112;Fill=$softTeal;Title='5';Body='main navigation sections in UI'},@{L=492;T=132;W=200;H=112;Fill=$softGold;Title='RAG';Body='chat assistant with source-aware answers'},@{L=712;T=132;W=200;H=112;Fill=$softPink;Title='PDF';Body='view and download support via backend'})
    foreach ($c in $cards) {
        Add-Card -Slide $slide -Left $c.L -Top $c.T -Width $c.W -Height $c.H -FillColor $c.Fill -LineColor $line | Out-Null
        Add-TextBox -Slide $slide -Left ($c.L+16) -Top ($c.T+14) -Width ($c.W-32) -Height 34 -Text $c.Title -FontSize 26 -Color $ink -Bold 1 | Out-Null
        Add-TextBox -Slide $slide -Left ($c.L+16) -Top ($c.T+50) -Width ($c.W-32) -Height 44 -Text $c.Body -FontSize 16 -Color $muted | Out-Null
    }
    Add-Card -Slide $slide -Left 52 -Top 274 -Width 424 -Height 190 -FillColor $navy -LineColor $navy | Out-Null
    Add-TextBox -Slide $slide -Left 74 -Top 294 -Width 372 -Height 28 -Text 'Major Functional Outcomes' -FontSize 20 -Color $paper -Bold 1 | Out-Null
    Add-TextBox -Slide $slide -Left 74 -Top 334 -Width 360 -Height 108 -Text "- Students can browse academic files through a structured hierarchy.`r`n- AI chat returns contextual answers using retrieved chunks.`r`n- Chat sessions can be created, renamed, deleted, and revisited.`r`n- Optional diagram generation improves visual explanation for long answers." -FontSize 17 -Color $softBlue | Out-Null
    Add-Card -Slide $slide -Left 500 -Top 274 -Width 412 -Height 190 -FillColor $cream -LineColor $line | Out-Null
    Add-TextBox -Slide $slide -Left 522 -Top 294 -Width 360 -Height 28 -Text 'Engineering Value' -FontSize 20 -Color $ink -Bold 1 | Out-Null
    Add-TextBox -Slide $slide -Left 522 -Top 334 -Width 360 -Height 110 -Text "The project is not only a file browser. It adds an academic question-answering layer on top of the content repository, making the system more useful for revision, exam preparation, and quick concept lookup." -FontSize 18 -Color $muted | Out-Null

    $slide = $presentation.Slides.Add(8,12); $bg=$slide.Shapes.AddShape(1,0,0,960,540); $bg.Fill.ForeColor.RGB=$cream; $bg.Line.Visible=0
    Add-Tag -Slide $slide -Left 52 -Top 30 -Width 192 -Height 26 -Text '04 Result and Discussion' -FillColor $softBlue -TextColor $blue
    Add-TextBox -Slide $slide -Left 52 -Top 64 -Width 460 -Height 42 -Text 'Project Metrics and Current Output' -FontSize 26 -Color $ink -FontName 'Georgia' -Bold 1 | Out-Null
    Add-Card -Slide $slide -Left 52 -Top 126 -Width 476 -Height 340 -FillColor $paper -LineColor $line | Out-Null
    Add-TextBox -Slide $slide -Left 74 -Top 146 -Width 320 -Height 28 -Text 'Content Available in Repo' -FontSize 20 -Color $ink -Bold 1 | Out-Null
    $chartX = 110; $baseY = 414; $barW = 74; $gap = 58
    $bars = @(@{Label='Books';Value=6;Color=$blue},@{Label='PYQs';Value=4;Color=$gold},@{Label='Notes';Value=0;Color=$teal})
    foreach ($b in $bars) {
        $height = 28 * $b.Value
        if ($height -eq 0) { $height = 8 }
        Add-Card -Slide $slide -Left $chartX -Top ($baseY-$height) -Width $barW -Height $height -FillColor $b.Color -LineColor $b.Color | Out-Null
        Add-TextBox -Slide $slide -Left ($chartX-6) -Top ($baseY-$height-28) -Width 86 -Height 22 -Text ([string]$b.Value) -FontSize 14 -Color $ink -Bold 1 -Alignment 2 | Out-Null
        Add-TextBox -Slide $slide -Left ($chartX-10) -Top 424 -Width 94 -Height 26 -Text $b.Label -FontSize 14 -Color $muted -Alignment 2 | Out-Null
        $chartX += ($barW+$gap)
    }
    Add-TextBox -Slide $slide -Left 74 -Top 188 -Width 390 -Height 140 -Text "Measured directly from the current repository:`r`n- 6 PDF books`r`n- 4 PYQs`r`n- 0 notes currently added`r`n- 1 visible branch dataset in books folder (CSE)`r`n`r`nThis shows the system is already wired for real content and can grow by simply placing more PDFs into the folder structure." -FontSize 17 -Color $muted | Out-Null
    Add-Card -Slide $slide -Left 552 -Top 126 -Width 356 -Height 340 -FillColor $navy -LineColor $navy | Out-Null
    Add-TextBox -Slide $slide -Left 574 -Top 146 -Width 308 -Height 28 -Text 'Technical Discussion' -FontSize 20 -Color $paper -Bold 1 | Out-Null
    Add-TextBox -Slide $slide -Left 574 -Top 188 -Width 300 -Height 210 -Text "- SQLite stores document, chunk, student, and search-history metadata.`r`n- FAISS index file is already present for vector retrieval.`r`n- SentenceTransformer embeddings and cross-encoder reranking improve relevance.`r`n- Groq LLM generation turns retrieved chunks into readable answers.`r`n- The architecture is modular enough for future evaluation, scaling, and UI polish." -FontSize 17 -Color $softBlue | Out-Null

    $slide = $presentation.Slides.Add(9,12); $bg=$slide.Shapes.AddShape(1,0,0,960,540); $bg.Fill.ForeColor.RGB=$navy; $bg.Line.Visible=0
    Add-Tag -Slide $slide -Left 52 -Top 30 -Width 192 -Height 26 -Text '04 Result and Discussion' -FillColor $blue -TextColor $paper
    Add-TextBox -Slide $slide -Left 52 -Top 64 -Width 500 -Height 42 -Text 'Benefits and Current Limitations' -FontSize 26 -Color $paper -FontName 'Georgia' -Bold 1 | Out-Null
    Add-Card -Slide $slide -Left 52 -Top 132 -Width 392 -Height 312 -FillColor $paper -LineColor $paper -FillTransparency 0.05 -LineTransparency 0.75 | Out-Null
    Add-TextBox -Slide $slide -Left 74 -Top 152 -Width 340 -Height 28 -Text 'Benefits Achieved' -FontSize 20 -Color $paper -Bold 1 | Out-Null
    Add-TextBox -Slide $slide -Left 74 -Top 194 -Width 332 -Height 220 -Text "- Reduces search effort by organizing files into a guided academic hierarchy.`r`n- Supports faster revision through concise AI-generated explanations.`r`n- Grounds answers in retrieved study content and references source files.`r`n- Keeps the system extensible for more data and branches.`r`n- Blends content management and AI support in one student-friendly workflow." -FontSize 18 -Color $softBlue | Out-Null
    Add-Card -Slide $slide -Left 476 -Top 132 -Width 432 -Height 312 -FillColor $paper -LineColor $paper -FillTransparency 0.05 -LineTransparency 0.75 | Out-Null
    Add-TextBox -Slide $slide -Left 498 -Top 152 -Width 380 -Height 28 -Text 'Current Limitations' -FontSize 20 -Color $paper -Bold 1 | Out-Null
    Add-TextBox -Slide $slide -Left 498 -Top 194 -Width 372 -Height 220 -Text "- Dataset is still limited in volume and branch coverage.`r`n- Notes folder is prepared but not populated in the current repo.`r`n- Evaluation metrics such as precision or response accuracy are not yet reported.`r`n- OCR and local model dependencies may need careful environment setup.`r`n- Authentication and personalized recommendation flows are still future scope." -FontSize 18 -Color $softBlue | Out-Null
    Add-Tag -Slide $slide -Left 52 -Top 466 -Width 856 -Height 30 -Text 'Discussion takeaway: the project successfully proves the concept and is ready for richer datasets, evaluation, and deployment improvements.' -FillColor $gold -TextColor $ink

    $slide = $presentation.Slides.Add(10,12); $bg=$slide.Shapes.AddShape(1,0,0,960,540); $bg.Fill.ForeColor.RGB=$paper; $bg.Line.Visible=0
    Add-Circle -Slide $slide -Left 720 -Top -40 -Size 220 -FillColor $softBlue -Transparency 0.25 | Out-Null
    Add-Circle -Slide $slide -Left 770 -Top 300 -Size 150 -FillColor $softTeal -Transparency 0.3 | Out-Null
    Add-Tag -Slide $slide -Left 52 -Top 30 -Width 205 -Height 26 -Text '05 Conclusion and Future Work' -FillColor $softGold -TextColor $ink
    Add-TextBox -Slide $slide -Left 52 -Top 64 -Width 460 -Height 42 -Text 'Conclusion and Future Work' -FontSize 26 -Color $ink -FontName 'Georgia' -Bold 1 | Out-Null
    Add-Card -Slide $slide -Left 52 -Top 126 -Width 404 -Height 308 -FillColor $navy -LineColor $navy | Out-Null
    Add-TextBox -Slide $slide -Left 74 -Top 148 -Width 356 -Height 28 -Text 'Conclusion' -FontSize 20 -Color $paper -Bold 1 | Out-Null
    Add-TextBox -Slide $slide -Left 74 -Top 192 -Width 340 -Height 200 -Text "UniGuide demonstrates how AI can make academic resources easier to access and more useful.`r`n`r`nBy combining structured browsing, document retrieval, and context-aware answer generation, the project turns a static resource collection into an interactive study assistant for students." -FontSize 18 -Color $softBlue | Out-Null
    Add-Card -Slide $slide -Left 488 -Top 126 -Width 420 -Height 308 -FillColor $cream -LineColor $line | Out-Null
    Add-TextBox -Slide $slide -Left 510 -Top 148 -Width 372 -Height 28 -Text 'Future Work' -FontSize 20 -Color $ink -Bold 1 | Out-Null
    Add-TextBox -Slide $slide -Left 510 -Top 192 -Width 360 -Height 200 -Text "- Add in-app PDF viewer and deeper semantic search.`r`n- Expand to more branches, semesters, and note collections.`r`n- Introduce authentication and personalized recommendations.`r`n- Add evaluation metrics and user feedback tracking.`r`n- Prepare cloud deployment and easier multi-device access." -FontSize 18 -Color $muted | Out-Null
    Add-Tag -Slide $slide -Left 52 -Top 456 -Width 410 -Height 28 -Text 'Editable note: replace slide 1 placeholders with actual student and mentor details.' -FillColor $softBlue -TextColor $blue
    Add-Tag -Slide $slide -Left 472 -Top 456 -Width 182 -Height 28 -Text 'Prepared from repo content' -FillColor $softTeal -TextColor $teal

    $presentation.SaveAs($OutputPath)
    $presentation.Close()
    $ppt.Quit()
    Get-Item $OutputPath | Select-Object FullName,Length,LastWriteTime
}
finally {
    if ($presentation -ne $null) { [System.Runtime.Interopservices.Marshal]::ReleaseComObject($presentation) | Out-Null }
    if ($ppt -ne $null) { [System.Runtime.Interopservices.Marshal]::ReleaseComObject($ppt) | Out-Null }
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}
