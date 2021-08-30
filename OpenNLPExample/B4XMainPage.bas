B4A=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=9.85
@EndOfDesignText@
#Region Shared Files
#CustomBuildAction: folders ready, %WINDIR%\System32\Robocopy.exe,"..\..\Shared Files" "..\Files"
'Ctrl + click to sync files: ide://run?file=%WINDIR%\System32\Robocopy.exe&args=..\..\Shared+Files&args=..\Files&FilesSync=True
#End Region

'github desktop ide://run?file=%WINDIR%\System32\cmd.exe&Args=/c&Args=github&Args=..\..\

Sub Class_Globals
	Private Root As B4XView
	Private xui As XUI
	Private B4XFloatTextField1 As B4XFloatTextField
	Private BBCodeView1 As BBCodeView
	Private nlp As OpenNLP
	Private NER_Models As List
	Private TokenizerModel As Object
	Private SentenceModel As Object
	Private DetokenizerModel As Object
	Private LangDetectModel As Object
	Private Stemmer As Object
	Private LemmaModel As JavaObject 'using JavaObject instead of Object just for the IsInitialized check.
	Private ChunkModel As JavaObject
	Private POSModel As JavaObject
	Private SentimentDoccatModel As JavaObject
	Private ForumDoccatModel As JavaObject
	Private TextEngine As BCTextEngine
	Private ByteConverter As ByteConverter
	Private btnAnalyze As B4XView
	Private AnotherProgressBar1 As AnotherProgressBar
	Private lblLanguage As B4XView
	Private rbNER As B4XView
	Private rbLemma As B4XView
	Private rbStem As B4XView
	Private rbPOS As B4XView
	Private rbChunk As B4XView
	Private rbSentiment As B4XView
	Private rbForumCategory As B4XView
	Private ModelsFolder As String
End Sub

Public Sub Initialize
End Sub

Private Sub B4XPage_Created (Root1 As B4XView)
	Root = Root1
	Root.LoadLayout("MainPage")
	B4XPages.SetTitle(Me, "OpenNLP Example")
	TextEngine.Initialize(Root)
	nlp.Initialize
	NER_Models.Initialize
	ModelsFolder = File.Combine(File.DirApp, "\..\..\Models")
	btnAnalyze.Enabled = False
	For Each ner As String In Array("en-ner-person.bin", "en-ner-organization.bin", "en-ner-date.bin", "en-ner-location.bin", "en-ner-money.bin", "en-ner-percentage.bin", "en-ner-time.bin")
		Wait For (nlp.LoadModelAsync(nlp.MODEL_NAME_FINDER, ModelsFolder, ner)) Complete (Model As Object)
		NER_Models.Add(Model)
	Next
	TokenizerModel = nlp.LoadModel(nlp.MODEL_TOKENIZER, ModelsFolder, "opennlp-en-ud-ewt-tokens-1.0-1.9.3.bin")
	SentenceModel = nlp.LoadModel(nlp.MODEL_SENTENCE, ModelsFolder, "opennlp-en-ud-ewt-sentence-1.0-1.9.3.bin")
	DetokenizerModel = nlp.LoadModel(nlp.MODEL_DETOKENIZER_RULES, ModelsFolder, "en-detokenizer-rules.txt")
	LangDetectModel = nlp.LoadModel(nlp.MODEL_LANGUAGE_DETECTOR, ModelsFolder, "langdetect-183.bin")
	POSModel = nlp.LoadModel(nlp.MODEL_POS_TAGGER, ModelsFolder, "en-pos-maxent.bin")

	Stemmer = nlp.CreateStemmer("ENGLISH")
	btnAnalyze.Enabled = True
	AnotherProgressBar1.Visible = False
	
	rbNER.Checked = True
	btnExampleText_Click
	
End Sub


Private Sub btnAnalyze_Click
	'removing square brackets to prevent issues with broken bbcode tags (another option is to add [plain] to tags with '[').
	Dim text As String = B4XFloatTextField1.Text.Replace("[", "")
	Dim langs() As NLPLanguage = nlp.DetectLanguages(LangDetectModel, text)
	lblLanguage.Text = IIf(langs.Length > 0, langs(0).Language, "")
	Dim paragraph As NLPParagraph
	If rbForumCategory.Checked Then
		paragraph = nlp.TokenizeWhitespace(Null, text) 'simpler tokenizer provides better results as it is not pure English content.
		'The Doccat trainer uses this tokenizer which means that it might provide better results with the movies sentiment detector as well.
	Else
		paragraph = nlp.TokenizeLearnable(SentenceModel, TokenizerModel, text)
	End If
	Dim ColorsLegend As StringBuilder
	ColorsLegend.Initialize
	Dim ColorsMap As Map
	ColorsMap.Initialize
	Select True
		Case rbNER.Checked
			FindNames(paragraph, ColorsMap, ColorsLegend)
		Case rbLemma.Checked
			nlp.POSTagging(POSModel, paragraph)
			If LemmaModel.IsInitialized = False Then
				LemmaModel = nlp.LoadModel(nlp.MODEL_LEMMATIZER, ModelsFolder, "en-lemmatizer.bin")
			End If
			nlp.Lemmatize(LemmaModel, paragraph)
			For Each Sen As NLPSentence In paragraph.Sentences
				For Each token As NLPToken In Sen.Tokens
					token.TokenText = token.Lemma 
				Next
			Next
		Case rbStem.Checked
			For Each Sen As NLPSentence In paragraph.Sentences
				For Each token As NLPToken In Sen.Tokens
					token.TokenText = nlp.Stem(Stemmer, token.TokenText) 
				Next
			Next
		Case rbPOS.Checked
			TagPartOfSpeech(paragraph, ColorsMap, ColorsLegend)
		Case rbChunk.Checked
			Chunk(paragraph, ColorsMap, ColorsLegend)
		Case rbSentiment.Checked
			Sentiment(paragraph)
			Return
		Case rbForumCategory.Checked
			ForumDoccat(paragraph)
			Return
	End Select
	Dim s As String = nlp.Detokenize(DetokenizerModel, paragraph, "", CRLF)
	BBCodeView1.Text = IIf(ColorsLegend.Length > 0, ColorsLegend.ToString & CRLF & CRLF & s, s)
End Sub

Private Sub Sentiment (Paragraph As NLPParagraph)
	If SentimentDoccatModel.IsInitialized = False Then
		SentimentDoccatModel = nlp.LoadModel(nlp.MODEL_DOCUMENT_CATEGORIZER, ModelsFolder, "en-movies.bin")
	End If
	nlp.Categorize(SentimentDoccatModel, Paragraph, False)
	Dim sb As StringBuilder
	sb.Initialize
	sb.Append(CategoriesToString(Paragraph))
	sb.Append($"
Dataset source (Large Movie Review Dataset): [url]http://ai.stanford.edu/~amaas/data/sentiment/[/url]"$)
	BBCodeView1.Text = sb.ToString
End Sub

Private Sub ForumDoccat (Paragraph As NLPParagraph)
	If ForumDoccatModel.IsInitialized = False Then
		ForumDoccatModel = nlp.LoadModel(nlp.MODEL_DOCUMENT_CATEGORIZER, ModelsFolder, "question_or_library.bin")
	End If
	nlp.Categorize(ForumDoccatModel, Paragraph, False)
	Dim sb As StringBuilder
	sb.Initialize
	sb.Append("Document categorizer with a model based on forum threads. It tries to detect whether a post is a question or a library.").Append(CRLF).Append(CRLF)
	sb.Append(CategoriesToString(Paragraph))
	sb.Append($"
Expected format: username title firstpost"$)
	BBCodeView1.Text = sb.ToString
End Sub

Private Sub CategoriesToString (Paragraph As NLPParagraph) As String
	Dim sb As StringBuilder
	sb.Initialize
	For Each Cat As NLPCategory In Paragraph.Categories
		Dim bold As Boolean = Cat.CategoryText = Paragraph.BestCategory.CategoryText
		If bold Then sb.Append("[b]")
		sb.Append(Cat.CategoryText).Append(": ").Append($"$1.0{Cat.Probability * 100}%"$).Append(CRLF)
		If bold Then sb.Append("[/b]")
	Next
	Return sb.ToString
End Sub

Private Sub Chunk (Paragraph As NLPParagraph, ColorsMap As Map, ColorsLegend As StringBuilder)
	If ChunkModel.IsInitialized = False Then
		ChunkModel = nlp.LoadModel(nlp.MODEL_CHUNKER, ModelsFolder, "en-chunker.bin")
	End If
	nlp.POSTagging(POSModel, Paragraph)
	nlp.Chunk(ChunkModel, Paragraph)
	For Each Sen As NLPSentence In Paragraph.Sentences
		For Each Chnk As NLPSpan In Sen.ChunksSpans
			Dim clr As String = GetTypeColor(ColorsMap, ColorsLegend, Chnk.SpanType)
			For i = Chnk.SpanStart To Chnk.SpanEnd - 1
				Dim token As NLPToken = Sen.Tokens.Get(i)
				token.TokenText = IIf(i = Chnk.SpanStart, "|", "") & $"[color=${clr}]${token.TokenText}[/color]"$ & IIf(i = Chnk.SpanEnd - 1, "|", "")
			Next
		Next
	Next
End Sub

Private Sub FindNames (Paragraph As NLPParagraph, ColorsMap As Map, ColorsLegend As StringBuilder)
	For Each ner As Object In NER_Models
		nlp.FindNames(ner, Paragraph)
	Next
	For Each name As NLPName In Paragraph.Names
		Dim NameType As String = name.TokensSpan.SpanType
		Dim clr As String = GetTypeColor(ColorsMap, ColorsLegend, NameType)
		For i = name.TokensSpan.SpanStart To name.TokensSpan.SpanEnd - 1
			Dim token As NLPToken = name.Sentence.Tokens.Get(i)
			token.TokenText = Mark(token.TokenText, clr, True)
		Next
	Next
End Sub

Private Sub TagPartOfSpeech (Paragraph As NLPParagraph, ColorsMap As Map, ColorsLegend As StringBuilder)
	nlp.POSTagging(POSModel, Paragraph)
	For Each sen As NLPSentence In Paragraph.Sentences
		For Each token As NLPToken In sen.Tokens
			token.TokenText = Mark(token.TokenText, GetTypeColor(ColorsMap, ColorsLegend, token.POSTag), False)
		Next
	Next
End Sub

Private Sub GetTypeColor (ColorsMap As Map, ColorsLegend As StringBuilder, EntityType As String) As String
	If ColorsMap.ContainsKey(EntityType) = False Then
		Dim clr As String = RandomHexColor
		ColorsMap.Put(EntityType, clr)
		If ColorsLegend.Length > 0 Then ColorsLegend.Append(" ")
		ColorsLegend.Append(Mark(EntityType, clr, True))
	End If
	Return ColorsMap.Get(EntityType)
End Sub

Private Sub Mark(t As String, clr As String, bold As Boolean) As String
	Dim s As String = $"[u thickness=3 color=${clr}]${t}[/u]"$
	If bold Then s = $"[b]${s}[/b]"$
	Return s
End Sub

Private Sub RandomHexColor As String
	Return "0x" & ByteConverter.HexFromBytes(ByteConverter.IntsToBytes(Array As Int(Rnd(xui.Color_Black, xui.Color_White))))
End Sub

Private Sub BBCodeView1_LinkClicked (URL As String)
	Dim fx As JFX
	fx.ShowExternalDocument(URL)
End Sub

Private Sub btnExampleText_Click
	Dim s As String
	Select True
		Case rbLemma.Checked, rbStem.Checked
			s = "He sat near the table and ate ice cream and two cakes."	
		Case rbSentiment.Checked
			s = $"This is essentially Vikings with laughs.
Very well done and markedly funny.
Entertaining and also very timely, what with the recent finale of Game of Thrones.
This helps to fill the medieval gap but with a new twist, so this isn't just another poor copy as we've seen start to crop up.
Bravo to Norway for producing this great hit, and extra kudos to the cast and crew for filming each scene twice (and most likely many times more) in both Norwegian and English.
Hopefully word spreads on this hidden gem and Netflix picks this up for the 2nd season (already filmed)."$
		Case rbForumCategory.Checked
			s = $"Erel [B4X] CLVTree - Tree View CLVTree extends xCustomListView and turns it into a tree view
[ATTACH type="full" alt="1626084972760.png"]116228[/ATTACH]  Usage: 1. Add a CustomListView with the designer. 2. Initialize CLVTree and add items: [code]
 Tree.Initialize(CustomListView1)    
  For i = 1 To 10
  Dim item As CLVTreeItem = Tree.AddItem(Tree.Root, "Item #{i}", Null, "")     Next [/code]  More information in the attached cross platform example.  [B]Notes[/B]  - The UI Is lazy loaded, this means that the views are only created For the visible items And they are later reused. - The items text can be a regular string Or CSBuilder. - To allow making multiple changes efficiently, the UI isn't updated immediately. You should call Tree.Refresh to update it. -
As the code uses the new IIf And As keywords, it requires B4i 7.5+, B4J 9.1+ Or B4A 11+. - There are currently no animations. Might be added in the future.  [B]Updates[/B]  v1.01 - Tree.Clear method. Removes all items."$
		Case Else
			s = File.ReadString(File.DirAssets, "default text.txt")
	End Select
	B4XFloatTextField1.Text = s
	BBCodeView1.Text = ""
	lblLanguage.Text = ""
End Sub