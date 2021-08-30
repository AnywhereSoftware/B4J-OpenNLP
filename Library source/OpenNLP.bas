B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=9.1
@EndOfDesignText@
'ide://run?file=%PROJECT%\build.bat&WorkingDirectory=%PROJECT%\
'open the b4xlib manifest file with notepad++ ide://run?file=%COMSPEC%&args=/c&args=%PROJECT%\manifest.txt
'github desktop ide://run?file=%WINDIR%\System32\cmd.exe&Args=/c&Args=github&Args=..\..\
Sub Class_Globals
	Private jMe As JavaObject
	Type NLPLanguage (Language As String, Confidence As Double)
	Type NLPSpan (SpanStart As Int, SpanEnd As Int, Probability As Double, SpanType As String)
	Type NLPParagraph (Text As String, Sentences As List, Names As List, BestCategory As NLPCategory, Categories As List)
	Type NLPSentence (TextSpan As NLPSpan, SentenceText As String, Paragraph As NLPParagraph, Tokens As List, ChunksSpans As List)
	Type NLPToken (SentenceSpan As NLPSpan, TokenText As String, Sentence As NLPSentence, POSTag As String, Lemma As String)
	Type NLPName (TokensSpan As NLPSpan, NameText As String, Sentence As NLPSentence)
	Type NLPCategory (CategoryText As String, Probability As Double)
	Public Const MODEL_TOKENIZER = "opennlp.tools.tokenize.TokenizerModel", MODEL_SENTENCE = "opennlp.tools.sentdetect.SentenceModel", MODEL_NAME_FINDER = "opennlp.tools.namefind.TokenNameFinderModel" As String
	Public Const MODEL_LANGUAGE_DETECTOR = "opennlp.tools.langdetect.LanguageDetectorModel", MODEL_DOCUMENT_CATEGORIZER = "opennlp.tools.doccat.DoccatModel" As String
	Public Const MODEL_DETOKENIZER_RULES As String = "opennlp.tools.tokenize.DetokenizationDictionary"
	Public Const MODEL_POS_TAGGER = "opennlp.tools.postag.POSModel", MODEL_LEMMATIZER = "opennlp.tools.lemmatizer.LemmatizerModel" As String
	Public Const MODEL_CHUNKER = "opennlp.tools.chunker.ChunkerModel" As String
End Sub

Public Sub Initialize
	jMe = Me
End Sub

'Asynchronously loads a model.
'ModelType - One of the MODEL constants.
'<code>Wait For (nlp.LoadModelAsync(nlp.MODEL_TOKENIZER, File.DirAssets, "model-file.bin")) Complete (Model As Object)</code>
Public Sub LoadModelAsync (ModelType As String, ModelDir As String, ModelFileName As String) As ResumableSub
	Dim in As InputStream = File.OpenInput(ModelDir, ModelFileName)
	Wait For (jMe.RunMethod("newInstanceAsync", Array(ModelType, Array(in)))) RunAsync_Complete (Success As Boolean, MODEL As Object)
	in.Close
	Return MODEL
End Sub

'Loads a model.
'ModelType - One of the MODEL constants.
Public Sub LoadModel (ModelType As String, ModelDir As String, ModelFileName As String) As Object
	Dim jo As JavaObject
	Dim in As InputStream = File.OpenInput(ModelDir, ModelFileName)
	jo.InitializeNewInstance(ModelType, Array(in))
	in.Close
	Return jo
End Sub


'Detects the text language. Returns an array of NLPLanguages sorted in descending order.
Public Sub DetectLanguages (LanguageModel As Object, Text As String) As NLPLanguage()
	Dim ld As JavaObject
	ld.InitializeNewInstance("opennlp.tools.langdetect.LanguageDetectorME", Array(LanguageModel))
	Dim languages() As Object = ld.RunMethod("predictLanguages", Array(Text))
	Dim res(languages.Length) As NLPLanguage
	For i = 0 To languages.Length - 1
		Dim l As JavaObject = languages(i)
		res(i) = CreateNLPLanguage(l.RunMethod("getLang", Null), l.RunMethod("getConfidence", Null))
	Next
	Return res
End Sub

'Tokenizes the text based on a whitespace tokenizer.
Public Sub TokenizeWhitespace(SentenceModel As Object, Text As String) As NLPParagraph
	Dim wt As JavaObject
	wt = wt.InitializeStatic("opennlp.tools.tokenize.WhitespaceTokenizer").GetField("INSTANCE")
	Return TokenizeImpl(SentenceModel, wt, Text)
End Sub

'Tokenizes the text based on a learnable tokenizer.
Public Sub TokenizeLearnable(SentenceModel As Object, TokenizerModel As Object, Text As String) As NLPParagraph
	Dim tm As JavaObject
	tm.InitializeNewInstance("opennlp.tools.tokenize.TokenizerME",Array(TokenizerModel))
	Return TokenizeImpl(SentenceModel, tm, Text)
End Sub

Private Sub TokenizeImpl(SentenceModel As Object, Tokenizer As JavaObject, Text As String) As NLPParagraph
	Dim Paragraph As NLPParagraph
	Paragraph.Initialize
	Paragraph.Text = Text
	Paragraph.Sentences.Initialize
	Paragraph.Names.Initialize
	If SentenceModel = Null Then
		Dim sen As NLPSentence
		sen.Initialize
		sen.Tokens.Initialize
		sen.Paragraph = Paragraph
		sen.TextSpan = CreateNLPSpan(0, Text.Length, 0, "")
		sen.SentenceText = Paragraph.Text.SubString2(sen.TextSpan.SpanStart, sen.TextSpan.SpanEnd)
		Paragraph.Sentences.Add(sen)
	Else
		Dim sd As JavaObject
		sd.InitializeNewInstance("opennlp.tools.sentdetect.SentenceDetectorME", Array(SentenceModel))
		Dim Result() As Object = sd.RunMethod("sentPosDetect", Array(Text))
		For i = 0 To Result.Length -1
			Dim sen As NLPSentence
			sen.Initialize
			sen.Tokens.Initialize
			sen.Paragraph = Paragraph
			sen.TextSpan = CreateNLPSpanFromJavaSpan(Result(i))
			sen.SentenceText = Paragraph.Text.SubString2(sen.TextSpan.SpanStart, sen.TextSpan.SpanEnd)
			Paragraph.Sentences.Add(sen)
		Next
	End If
	For Each sentence As NLPSentence In Paragraph.Sentences
		Dim spans() As Object = Tokenizer.RunMethod("tokenizePos", Array(sentence.SentenceText))
		For Each span As JavaObject In spans
			Dim token As NLPToken
			token.Initialize
			token.SentenceSpan = CreateNLPSpanFromJavaSpan(span)
			token.Sentence = sentence
			token.TokenText = sentence.SentenceText.SubString2(token.SentenceSpan.SpanStart, token.SentenceSpan.SpanEnd)
			sentence.Tokens.Add(token)
		Next
	Next
	Return Paragraph
End Sub

Private Sub GetSentenceTokens(sen As NLPSentence) As String()
	Dim res(sen.Tokens.Size) As String
	For i = 0 To res.Length - 1
		res(i) = sen.Tokens.Get(i).As(NLPToken).TokenText
	Next
	Return res
End Sub

Private Sub GetSentencePOSTags(sen As NLPSentence) As String()
	Dim res(sen.Tokens.Size) As String
	For i = 0 To res.Length - 1
		res(i) = sen.Tokens.Get(i).As(NLPToken).POSTag
	Next
	Return res
End Sub

'Name entity recognition. The found entities (NLPNames) are added to Paragraph.Names.
Public Sub FindNames(NameFinderModel As Object, Paragraph As NLPParagraph)
	Dim finder As JavaObject
	finder.InitializeNewInstance("opennlp.tools.namefind.NameFinderME", Array(NameFinderModel))
	For Each sentence As NLPSentence In Paragraph.Sentences
		Dim spans() As Object = finder.RunMethod("find", Array(GetSentenceTokens(sentence)))
		For Each span As JavaObject In spans
			Dim name As NLPName
			name.Initialize
			name.Sentence = sentence
			name.TokensSpan = CreateNLPSpanFromJavaSpan(span)
			SetNameText(name)
			Paragraph.Names.Add(name)
		Next
	Next
End Sub

'Categoriezes the document. Fills Paragraph.BestCategory and optionally Paragraph.Categories (if OnlyBestCategory = False).
'Note that Paragraph.Categories is unsorted.
'The text is treated as a single array of tokens.
Public Sub Categorize(DoccatModel As Object, Paragraph As NLPParagraph, OnlyBestCategory As Boolean) 
	Dim categorizer As JavaObject
	categorizer.InitializeNewInstance("opennlp.tools.doccat.DocumentCategorizerME", Array(DoccatModel))
	Dim d() As Double = categorizer.RunMethod("categorize", Array(GetAllTokens(Paragraph)))
	Dim maxid As Int = 0
	For i = 1 To d.Length - 1
		If d(i) > d(maxid) Then maxid = i
	Next
	Paragraph.BestCategory = CreateNLPCategory(categorizer.RunMethod("getCategory", Array(maxid)), d(maxid))
	If OnlyBestCategory = False Then
		Paragraph.Categories.Initialize
		For i = 0 To d.Length - 1
			Paragraph.Categories.Add(CreateNLPCategory(categorizer.RunMethod("getCategory", Array(i)), d(i)))
		Next
	End If
End Sub

Private Sub GetAllTokens (Paragraph As NLPParagraph) As String()
	Dim CountTokens As Int
	For Each sentence As NLPSentence In Paragraph.Sentences
		CountTokens = CountTokens + sentence.Tokens.Size
	Next
	Dim tokens(CountTokens) As String
	Dim i As Int
	For Each sentence As NLPSentence In Paragraph.Sentences
		For Each token As NLPToken In sentence.Tokens
			tokens(i) = token.TokenText
			i = i + 1
		Next
	Next
	Return tokens
End Sub

Private Sub SetNameText(Name As NLPName)
	Dim sb As StringBuilder
	sb.Initialize
	For i = Name.TokensSpan.SpanStart To Name.TokensSpan.SpanEnd - 1
		If sb.Length > 0 Then sb.Append(" ")
		sb.Append(Name.Sentence.Tokens.Get(i).As(NLPToken).TokenText)
	Next
	Name.NameText = sb.ToString
End Sub

'Builds a string from a the paragraph tokens based on a rules file.
'SplitMarker - String that will be added between the tokens.
'EndOfLine - String that will be appended to each sentence.
Public Sub Detokenize(DetokenizerModel As Object, Paragraph As NLPParagraph, SplitMarker As String, EndOfLine As String) As String
	Dim sb As StringBuilder
	sb.Initialize
	Dim jo As JavaObject
	jo.InitializeNewInstance("opennlp.tools.tokenize.DictionaryDetokenizer", Array(DetokenizerModel))
	For Each sentence As NLPSentence In Paragraph.Sentences
		If sb.Length > 0 Then sb.Append(EndOfLine)
		Dim tokens(sentence.Tokens.Size) As String
		For i = 0 To tokens.Length - 1
			tokens(i) = sentence.Tokens.Get(i).As(NLPToken).TokenText
		Next
		sb.Append(jo.RunMethod("detokenize", Array(tokens, SplitMarker)))
	Next
	Return sb.ToString
End Sub


'Creates a language specific stemmer, based on Porter Stemming algorithm.
'Language should be one of the following values: ARABIC, DANISH, DUTCH, CATALAN, ENGLISH, FINNISH, 
'FRENCH, GERMAN, GREEK, HUNGARIAN, INDONESIAN, IRISH, ITALIAN, NORWEGIAN, PORTER, PORTUGUESE, ROMANIAN, RUSSIAN, SPANISH, SWEDISH, TURKISH
Public Sub CreateStemmer(Language As String) As Object
	Dim stemmer As JavaObject
	stemmer.InitializeNewInstance("opennlp.tools.stemmer.snowball.SnowballStemmer", Array(Language))
	Return stemmer
End Sub

'Returns the stemmed word.
Public Sub Stem (Stemmer As Object, Word As String) As String
	Return Stemmer.As(JavaObject).RunMethod("stem", Array(Word))
End Sub

'Part Of Speech tagging. Fills the POSTag field of each token.
Public Sub POSTagging(Model As Object, Paragraph As NLPParagraph)
	Dim tagger As JavaObject
	tagger.InitializeNewInstance("opennlp.tools.postag.POSTaggerME", Array(Model))
	For Each sentence As NLPSentence In Paragraph.Sentences
		Dim tags() As String = tagger.RunMethod("tag", Array(GetSentenceTokens(sentence)))
		For i = 0 To tags.Length - 1
			sentence.Tokens.Get(i).As(NLPToken).POSTag = tags(i)
		Next
	Next
End Sub

'Lemmatizes the tokens. Fills the Lemma field of each token.
'Depends on the POS tags, which means that you need to first call POSTagging.
Public Sub Lemmatize(Model As Object, Paragraph As NLPParagraph)
	Dim lemmataizer As JavaObject
	lemmataizer.InitializeNewInstance("opennlp.tools.lemmatizer.LemmatizerME", Array(Model))
	For Each sentence As NLPSentence In Paragraph.Sentences
		Dim tags() As String = lemmataizer.RunMethod("lemmatize", Array(GetSentenceTokens(sentence), GetSentencePOSTags(sentence)))
		For i = 0 To tags.Length - 1
			sentence.Tokens.Get(i).As(NLPToken).Lemma = tags(i)
		Next
	Next
End Sub

'Chunks the sentences. Fills the ChunkSpans field of each sentence.
'Depends on the POS tags, which means that you need to first call POSTagging.
Public Sub Chunk(Model As Object, Paragraph As NLPParagraph)
	Dim chunker As JavaObject
	chunker.InitializeNewInstance("opennlp.tools.chunker.ChunkerME", Array(Model))
	For Each sentence As NLPSentence In Paragraph.Sentences
		sentence.ChunksSpans.Initialize
		Dim spans() As Object = chunker.RunMethod("chunkAsSpans", Array(GetSentenceTokens(sentence), GetSentencePOSTags(sentence)))
		For Each span As Object In spans
			sentence.ChunksSpans.Add(CreateNLPSpanFromJavaSpan(span))
		Next
	Next
End Sub


#if Java
import anywheresoftware.b4j.object.JavaObject;
import java.util.concurrent.Callable;
import java.util.ArrayList;
import java.util.List;
public Object runAsync(Object target, String method, Object[] params) {
	Object sender = new Object();
	BA.runAsync(getBA(), sender, "runasync_complete", new Object[] {false, null}, 
		new Callable<Object[]>() {
			public Object[] call() throws Exception {
				JavaObject jo = new JavaObject();
				jo.setObject(target);
				return new Object[] {true, jo.RunMethod(method, params)};
			}
		}
	);
	return sender;
}

public Object runAsyncPerSentence(Object target, String method, List<Object> sentences) {
	Object sender = new Object();
	BA.runAsync(getBA(), sender, "runasync_complete", new Object[] {false, null}, 
		new Callable<Object[]>() {
			public Object[] call() throws Exception {
				JavaObject jo = new JavaObject();
				jo.setObject(target);
				ArrayList<Object> result = new ArrayList<Object>();
				for (Object sen : sentences) {
					result.add(jo.RunMethod(method, new Object[] {sen}));
				}
				return new Object[] {true, result};
			}
		}
	);
	return sender;
}

public Object newInstanceAsync(String className, Object[] params) {
	Object sender = new Object();
	BA.runAsync(getBA(), sender, "runasync_complete", new Object[] {false, null}, 
		new Callable<Object[]>() {
			public Object[] call() throws Exception {
				JavaObject jo = new JavaObject();
				jo.InitializeNewInstance(className, params);
				return new Object[] {true, jo.getObject()};
			}
		}
	);
	return sender;
}

#End If

Private Sub CreateNLPLanguage (Language As String, Confidence As Double) As NLPLanguage
	Dim t1 As NLPLanguage
	t1.Initialize
	t1.Language = Language
	t1.Confidence = Confidence
	Return t1
End Sub

Private Sub CreateNLPSpanFromJavaSpan(jo As JavaObject) As NLPSpan
	Return CreateNLPSpan(jo.RunMethod("getStart", Null), jo.RunMethod("getEnd", Null), jo.RunMethod("getProb", Null), jo.RunMethod("getType", Null))
End Sub

Private Sub CreateNLPSpan (SpanStart As Int, SpanEnd As Int, Probability As Double, SpanType As Object) As NLPSpan
	Dim t1 As NLPSpan
	t1.Initialize
	t1.SpanStart = SpanStart
	t1.SpanEnd = SpanEnd
	t1.Probability = Probability
	t1.SpanType = IIf(SpanType = Null, "", SpanType)
	Return t1
End Sub

Private Sub CreateNLPCategory (CategoryText As String, Probability As Double) As NLPCategory
	Dim t1 As NLPCategory
	t1.Initialize
	t1.CategoryText = CategoryText
	t1.Probability = Probability
	Return t1
End Sub