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

'Ctrl + click to export as zip: ide://run?File=%B4X%\Zipper.jar&Args=Project.zip

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
	Private ChunkModel As Object
	Private Stemmer As Object
	Private LemmaModel As Object
	Private POSModel As Object
	Private SentimentDoccatModel As Object
	Private ForumDoccatModel As Object
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
	Dim ModelsFolder As String = File.Combine(File.DirApp, "\..\..\Models")
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
	LemmaModel = nlp.LoadModel(nlp.MODEL_LEMMATIZER, ModelsFolder, "en-lemmatizer.bin")
	ChunkModel = nlp.LoadModel(nlp.MODEL_CHUNKER, ModelsFolder, "en-chunker.bin")
	SentimentDoccatModel = nlp.LoadModel(nlp.MODEL_DOCUMENT_CATEGORIZER, ModelsFolder, "en-movies.bin")
	ForumDoccatModel = nlp.LoadModel(nlp.MODEL_DOCUMENT_CATEGORIZER, ModelsFolder, "question_or_library.bin")
	Stemmer = nlp.CreateStemmer("ENGLISH")
	btnAnalyze.Enabled = True
	AnotherProgressBar1.Visible = False
	B4XFloatTextField1.Text = File.ReadString(File.DirAssets, "default text.txt")
	rbNER.Checked = True
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
	nlp.Categorize(SentimentDoccatModel, Paragraph, False)
	Dim sb As StringBuilder
	sb.Initialize
	For Each cat As NLPCategory In Paragraph.Categories
		sb.Append(cat.CategoryText).Append(": ").Append(NumberFormat2(cat.Probability, 1, 2, 2, False)).Append(CRLF)
	Next
	sb.Append($"
Dataset source (Large Movie Review Dataset): [url]http://ai.stanford.edu/~amaas/data/sentiment/[/url]"$)
	BBCodeView1.Text = sb.ToString
End Sub

Private Sub ForumDoccat (Paragraph As NLPParagraph)
	nlp.Categorize(ForumDoccatModel, Paragraph, False)
	Dim sb As StringBuilder
	sb.Initialize
	For Each cat As NLPCategory In Paragraph.Categories
		sb.Append(cat.CategoryText).Append(": ").Append(NumberFormat2(cat.Probability, 1, 2, 2, False)).Append(CRLF)
	Next
	sb.Append($"
Expected format: username title firstpost"$)
	BBCodeView1.Text = sb.ToString
End Sub

Private Sub Chunk (Paragraph As NLPParagraph, ColorsMap As Map, ColorsLegend As StringBuilder)
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

Private Sub btnClear_Click
	B4XFloatTextField1.Text = ""
	B4XFloatTextField1.RequestFocusAndShowKeyboard
	BBCodeView1.Text = ""
	lblLanguage.Text = ""
End Sub

Private Sub RandomHexColor As String
	Return "0x" & ByteConverter.HexFromBytes(ByteConverter.IntsToBytes(Array As Int(Rnd(xui.Color_Black, xui.Color_White))))
End Sub

Private Sub BBCodeView1_LinkClicked (URL As String)
	Dim fx As JFX
	fx.ShowExternalDocument(URL)
End Sub