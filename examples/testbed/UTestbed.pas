{===============================================================================
  ___           _
 / __| ___ _ __| |_  ___ _ _ __ _ ™
 \__ \/ _ \ '_ \ ' \/ _ \ '_/ _` |
 |___/\___/ .__/_||_\___/_| \__,_|
          |_|
 AI Reasoning, Function-calling &
       Knowledge Retrieval

 Copyright © 2025-present tinyBigGAMES™ LLC
 All Rights Reserved.

 https://github.com/tinyBigGAMES/Sophora

 See LICENSE file for license information
===============================================================================}

{
  ===== USAGE NOTES =====
  * Download model from:
   - https://huggingface.co/tinybiggames/DeepHermes-3-Llama-3-8B-Preview-Q4_K_M-GGUF/resolve/main/deephermes-3-llama-3-8b-preview-q4_k_m.gguf?download=true
  * Place in your desired location, the examples expect:
   - C:/LLM/GGUF

  * Converting Models to GGUF Format:
   - You can convert a model to the GGUF format using an online converter
     available at Hugging Face Spaces
     (https://huggingface.co/spaces/ggml-org/gguf-my-repo).
     Note that you need a Hugging Face account, as the converted model will
     be saved to your account.

  * GPU Settings:
   - Setting `MainGPU` to `-1` will automatically select the best GPU
     available on your system.
   - Alternatively, you can specify a GPU by setting `MainGPU` to `0 - N`
     (where `N` is the GPU index).
   - For `MaxGPULayers`:
     - Setting it to `-1` will use all available layers on the GPU.
     - Setting it to `0` will use the CPU only.
     - Setting it to `1 - N` will offload a specific number of layers to the
       GPU.

  * Customizing Output:
   - You can configure various callbacks to control the model's output
     according to your needs.

  * Optimized for Local Inference:
   - Sophora is designed for efficient local inference on consumer-grade
     hardware. Using a 4-bit quantized model ensures fast loading and
     performance on modern consumer GPUs.

  * Get search api key from:
   - https://tavily.com/
   - You get 1000 free tokens per month
   - Create a an environment variable named "TAVILY_API_KEY" and set it to
     the search api key.

  * Explanation of SQL Static Macros (&text) and Dynamic Parameters (:text):
   1. SQL Static Macros (&text):
      - Purpose: Static macros are placeholders in your SQL query that are
        replaced with fixed values or strings at the time the SQL text is
        prepared.
      - How it works: When you use &text in your SQL statement, it acts as a
        macro that is replaced with a specific value or table name before the
        query is executed. This is typically used for SQL elements that don't
        change per execution, like table names or field names.
      - Example: If you have 'SELECT * FROM &table;' in your SQL text, and
        you set &table to 'users', the final SQL executed would be
        'SELECT * FROM users;'.
      - Analogy: Think of it like a "find and replace" that happens before
        the query runs.

   2. SQL Dynamic Parameters (:text):
      - Purpose: Dynamic parameters are used to securely insert variable data
        into SQL queries at runtime. They are typically used for values that
        can change, such as user input or variable data, and are often used
        to prevent SQL injection.
      - How it works: When you use :text in your SQL statement, it acts as a
        placeholder that will be dynamically replaced with an actual value at
        runtime. The value is passed separately from the SQL query, allowing
        for secure and flexible data handling.
      - Example: If you have 'SELECT * FROM users WHERE id = :userId;' in
        your SQL text, and you bind :userId to the value '42', the final SQL
        executed would be 'SELECT * FROM users WHERE id = 42;'.
      - Analogy: Think of it as a variable that gets its value just before
        the SQL query is run, making it possible to execute the same query
        with different data multiple times.
}

unit UTestbed;

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  System.JSON,
  Sophora.CLibs,
  Sophora.Utils,
  Sophora.Common,
  Sophora.Console,
  Sophora.Messages,
  Sophora.Inference,
  Sophora.Tools,
  Sophora.RAG;

procedure RunTests();

implementation

const
  CModelPath = 'C:/LLM/GGUF';

{
  This example demonstrates how to utilize DeepHermesLarge Language Model (LLM)
  in non-thinking mode to achieve the fastest possible response time. The
  function initializes a message queue and inference engine, loads the model,
  and processes a user query with immediate token streaming. The response is
  displayed in real-time as tokens are generated.

  Additionally, performance metrics, including input tokens, output tokens,
  and processing speed, are printed at the end of execution.
}
procedure Test01();
var
  // Stores the messages exchanged between user and LLM
  LMsg: TsoMessages;

  // Represents the inference engine responsible for running the LLM
  LInf: TsoInference;

  // Holds the count of input tokens processed by the model
  LInputTokens: Integer;

  // Holds the count of output tokens generated by the model
  LOutputTokens: Integer;

  // Represents the speed of token generation (tokens per second)
  LTokenSpeed: Single;
begin
  // Set console title
  soConsole.SetTitle('Sophora: Non-Thinking Mode');

  // Create instances of message handler and inference engine
  LMsg := TsoMessages.Create();
  LInf := TsoInference.Create();

  try
    // Set model path
    LInf.SetModelPath(CModelPath);

    // Load the LLM model; exit if loading fails
    if not LInf.LoadModel() then Exit;

    // Define an event to handle each token as it's generated
    LInf.NextTokenEvent :=
      procedure(const AToken: string)
      begin
        // Print generated tokens in green for real-time display
        soConsole.Print(soCSIFGGreen + AToken);
      end;

    // Add a user query to the message queue
    LMsg.Add(soUser, 'who is bill gates?');

    // Print the user question with formatting
    soConsole.PrintLn('Question: %s%s' + soCRLF, [soCSIFGCyan + soCRLF, LMsg.LastUser()]);

    // Print response header
    soConsole.PrintLn('Response:');

    // Execute inference with the provided user query
    if LInf.Run(LMsg) then
    begin
      // Retrieve and display performance metrics
      LInf.Performance(@LInputTokens, @LOutputTokens, @LTokenSpeed);
      soConsole.PrintLn(soCRLF + soCRLF + 'Performance:' + soCRLF +
        soCSIFGYellow + 'Input : %d tokens' + soCRLF +
        'Output: %d tokens' + soCRLF +
        'Speed : %3.2f tokens/sec',
        [LInputTokens, LOutputTokens, LTokenSpeed]);
    end
    else
    begin
      // Display error message in red if inference fails
      soConsole.PrintLn(soCRLF + soCRLF + soCSIFGRed + 'Errors: %s', [LInf.GetError()]);
    end;
  finally
    // Free allocated resources to avoid memory leaks
    if Assigned(LInf) then LInf.Free();
    if Assigned(LMsg) then LMsg.Free();
  end;
end;


{
  This example demonstrates how to utilize DeepHermes Large Language Model
  (LLM) in "thinking" mode. Unlike the non-thinking mode, this mode enables
  deep reasoning and internal deliberation. The model is instructed to
  carefully analyze the problem, engage in systematic reasoning, and provide
  detailed thoughts within <think></think> XML tags before delivering a final
  answer.

  The function initializes a message queue and inference engine, loads the
  model, and processes a user query using a structured reasoning approach. The
  response includes both the AI's internal thought process and the final
  answer. Performance metrics, including input tokens, output tokens, and
  processing speed, are displayed at the end of execution.
}
procedure Test02();
var
  // Stores the messages exchanged between user and LLM
  LMsg: TsoMessages;

  // Represents the inference engine responsible for running the LLM
  LInf: TsoInference;

  // Holds the count of input tokens processed by the model
  LInputTokens: Integer;

  // Holds the count of output tokens generated by the model
  LOutputTokens: Integer;

  // Represents the speed of token generation (tokens per second)
  LTokenSpeed: Single;
begin
  // Set console title
  soConsole.SetTitle('Sophora: Thinking Mode');

  // Create instances of message handler and inference engine
  LMsg := TsoMessages.Create();
  LInf := TsoInference.Create();

  try
    // Set model path
    LInf.SetModelPath(CModelPath);

    // Load the LLM model; exit if loading fails
    if not LInf.LoadModel() then Exit;

    // Define an event to handle each token as it's generated
    LInf.NextTokenEvent :=
      procedure(const AToken: string)
      begin
        // Print generated tokens in green for real-time display
        soConsole.Print(soCSIFGGreen + AToken);
      end;

    // Provide a system instruction that enables deep reasoning mode
    LMsg.Add(soSystem, 'You are a deep thinking AI, you may use extremely long chains of thought to deeply consider the problem and deliberate with yourself via systematic reasoning processes to help come to a correct solution prior to answering. You should enclose your thoughts and internal monologue inside <think> </think> XML tags, and then provide your solution or response to the problem. After your thinking process, clearly state your final answer or conclusion outside the XML tags.');

    // Add a complex user query to be analyzed in deep thinking mode
    LMsg.Add(soUser, 'I walk on four legs in the morning, two legs at noon, and three legs in the evening. But beware, for this is not the famous riddle of the Sphinx. Instead, my journey is cyclical, and each stage is both an end and a beginning. I am not a creature, but I hold the essence of all creatures within me. What am I?');

    // Print the user question with formatting
    soConsole.PrintLn('Question: %s%s' + soCRLF, [soCSIFGCyan + soCRLF, soConsole.WrapTextEx(LMsg.LastUser(), 120-10)]);

    // Print response header
    soConsole.PrintLn('Response:');

    // Execute inference with the provided user query
    if LInf.Run(LMsg) then
    begin
      // Retrieve and display performance metrics
      LInf.Performance(@LInputTokens, @LOutputTokens, @LTokenSpeed);
      soConsole.PrintLn(soCRLF + soCRLF + 'Performance:' + soCRLF +
        soCSIFGYellow + 'Input : %d tokens' + soCRLF +
        'Output: %d tokens' + soCRLF +
        'Speed : %3.2f tokens/sec',
        [LInputTokens, LOutputTokens, LTokenSpeed]);
    end
    else
    begin
      // Display error message in red if inference fails
      soConsole.PrintLn(soCRLF + soCRLF + soCSIFGRed + 'Errors: %s', [LInf.GetError()]);
    end;
  finally
    // Free allocated resources to avoid memory leaks
    if Assigned(LInf) then LInf.Free();
    if Assigned(LMsg) then LMsg.Free();
  end;
end;


{
  This example demonstrates how to generate embeddings using a Large Language
  Model (LLM). Embeddings are numerical representations of textual data that
  can be used for tasks such as similarity search, clustering, and
  retrieval-augmented generation (RAG).

  This function initializes the embedding engine, loads the model, and
  processes a given prompt to generate its embedding vector. The resulting
  embeddings are printed to the console in a formatted manner.
}
procedure Test03();
var
  // Represents the embedding engine responsible for generating vector
  // representations
  LEmb: TsoEmbeddings;

  // Stores the resulting embedding vector (array of floating-point numbers)
  LResult: TArray<Single>;

  // Iterator for looping through embedding values
  I, LLen: Integer;

  // Holds the text prompt to be converted into an embedding vector
  LPrompt: string;

  // Formatting variable for comma separation in output
  LComma: string;
begin
  // Set console title
  soConsole.SetTitle('Sophora: Embeddings');

  // Create an instance of the embedding engine
  LEmb := TsoEmbeddings.Create();

  try
    // Set model path
    LEmb.SetModelPath(CModelPath);

    // Load the embedding model; exit if loading fails
    if not LEmb.LoadModel() then Exit;

    // Define the text prompt to be embedded
    LPrompt := 'Explain how data analysis supports machine learning.';

    // Print the input prompt with formatting
    soConsole.PrintLn('Prompt: %s%s' + soCRLF, [soCSIFGCyan + soCRLF, LPrompt]);

    // Generate the embedding vector from the given prompt
    LResult := LEmb.Generate(LPrompt);

    // Print the header for the embedding values
    soConsole.PrintLn('Embeddings:');

    // Get the length of the resulting embedding vector
    LLen := High(LResult) + 1;

    // Loop through the embedding vector and print values
    for I := 0 to LLen - 1 do
    begin
      if I <> LLen - 1 then
        LComma := ','
      else
        LComma := '';

      // Print each embedding value in green, formatted to six decimal places
      soConsole.Print(soCSIFGGreen + '%0.6f%s ', [LResult[I], LComma]);
    end;

    // Print a newline for formatting
    soConsole.PrintLn();

  finally
    // Free allocated resources to avoid memory leaks
    LEmb.Free();
  end;
end;

{
  This example demonstrates how to use the local SQLite3 database engine with
  the Sophora framework.

  It performs the following operations:
  1. Connects to an SQLite3 database named "articles.db".
  2. Drops the "articles" table if it already exists.
  3. Creates a new "articles" table.
  4. Inserts predefined articles into the table.
  5. Queries and displays the contents of the table in JSON format.

  This is the foundational step for implementing a full Retrieval-Augmented
  Generation (RAG) system.
}
procedure Test04();
const
  // SQL statement to remove the "articles" table if it already exists
  CDropTableSQL = 'DROP TABLE IF EXISTS articles';

  // SQL statement to create the "articles" table with a single TEXT column
  CCreateTableSQL = 'CREATE TABLE IF NOT EXISTS articles (' +
                    'headline TEXT' +
                    ');';

  // SQL statement to insert sample articles into the "articles" table
  CInsertArticlesSQL = 'INSERT INTO articles VALUES ' +
    '(''Shohei Ohtani''''s ex-interpreter pleads guilty to charges related to gambling and theft''), ' +
    '(''The jury has been selected in Hunter Biden''''s gun trial''), ' +
    '(''Larry Allen, a Super Bowl champion and famed Dallas Cowboy, has died at age 52''), ' +
    '(''After saying Charlotte, a lone stingray, was pregnant, aquarium now says she''''s sick''), ' +
    '(''An Epoch Times executive is facing money laundering charge'');';

  // SQL statement to select all records from the "articles" table
  CListArticles = 'SELECT * FROM articles';

var
  // Database object for handling SQLite operations
  LDb: TsoDatabase;
begin
  // Set console title
  soConsole.SetTitle('Sophora: Database');

  // Create an instance of the database engine
  LDb := TsoDatabase.Create();

  try
    // Open the SQLite database file
    if LDb.Open('articles.db') then
    begin
      // Drop the existing "articles" table if it exists
      if LDb.ExecuteSQL(CDropTableSQL) then
        soConsole.PrintLn('Removing "articles" table if it exists...')
      else
        soConsole.PrintLn('Error: %s', [LDb.GetError()]);

      // Create the "articles" table
      if LDb.ExecuteSQL(CCreateTableSQL) then
        soConsole.PrintLn('Created "articles" table...')
      else
        soConsole.PrintLn('Error: %s', [LDb.GetError()]);

      // Insert predefined articles into the table
      if LDb.ExecuteSQL(CInsertArticlesSQL) then
        soConsole.PrintLn('Added articles into "articles" table...')
      else
        soConsole.PrintLn('Error: %s', [LDb.GetError()]);

      // Query and display the articles as JSON
      if LDb.ExecuteSQL(CListArticles) then
      begin
        soConsole.PrintLn('Displaying "articles" table content...');
        soConsole.PrintLn(LDb.GetResponseText());
      end
      else
        soConsole.PrintLn('Error: %s', [LDb.GetError()]);

      // Close the database connection
      LDb.Close();
    end;
  finally
    // Free allocated database object to avoid memory leaks
    LDb.Free();
  end;
end;


{
  This example demonstrates how to use DeepHermes-3 to generate embeddings for a vector database,
  which is a key component of a Retrieval-Augmented Generation (RAG) system.

  The procedure performs the following steps:
  1. Opens an existing vector database (`vectors.db`).
  2. Adds sample documents to the database.
  3. Runs a series of test queries to retrieve the most relevant documents based on similarity.
  4. Displays results in a formatted table, showing query terms, retrieved document IDs,
     ranking, and similarity scores.

  The test queries include:
  - Basic keywords related to AI and machine learning.
  - Concept-based queries to test semantic understanding.
  - Reworded queries using synonyms to check generalization.
  - Long, natural-language queries to simulate RAG-like retrieval.
}
procedure Test05();
var
  // Represents the embedding engine responsible for generating vector
  // representations
  LEmb: TsoEmbeddings;

  // Object representing the vector database
  LVectorDB: TsoVectorDatabase;

  // JSON array to store search results
  LSearchResults: TJSONArray;

  // Array of test queries to evaluate search performance
  LQueries: array of string;

  // Loop variables for iterating through queries and results
  I, J: Integer;

  // JSON object representing a single search result
  LSearchResultObj: TJSONObject;

  // Stores document ID and similarity score
  LDocID: string;
  LScore: Single;

  // Column width variables for formatting the output table
  LQueryColWidth, LDocColWidth, LScoreColWidth: Integer;
  LRankColWidth, LLineWidth: Integer;

begin
  // Set console title
  soConsole.SetTitle('Sophora: Vector Database');

  // Create an instance of the embedding engine
  LEmb := TsoEmbeddings.Create();

  try
    // Set model path
    LEmb.SetModelPath(CModelPath);

    // Load embeddings model on the CPU
    if not LEmb.LoadModel(0, 0) then Exit;

    // Create an instance of the vector database
    LVectorDB := TsoVectorDatabase.Create();

    try
      // Open the vector database; exit if it fails
      if not LVectorDB.Open(LEmb, 'vectors.db') then Exit;

      // Add sample documents to the vector database
      soConsole.PrintLn('Adding documents...');
      LVectorDB.AddDocument('doc1', 'This is an example document.');
      LVectorDB.AddDocument('doc2', 'Another piece of text related to AI.');
      LVectorDB.AddDocument('doc3', 'This document is about machine learning and AI.');

      // Define test queries
      SetLength(LQueries, 17);
      LQueries[0] := 'AI';
      LQueries[1] := 'machine learning';
      LQueries[2] := 'document';
      LQueries[3] := 'example';
      LQueries[4] := 'related to AI';

      // Concept-Based Queries
      LQueries[5] := 'Neural networks';
      LQueries[6] := 'Deep learning techniques';
      LQueries[7] := 'Artificial intelligence advancements';
      LQueries[8] := 'Text similarity in AI';
      LQueries[9] := 'Training large language models';

      // Reworded Queries (Synonyms)
      LQueries[10] := 'intelligent algorithms';
      LQueries[11] := 'automated learning';
      LQueries[12] := 'document text';
      LQueries[13] := 'a file related to artificial intelligence';

      // Long, Natural Language Queries (RAG-style)
      LQueries[14] := 'What is the relationship between AI and machine learning?';
      LQueries[15] := 'Can you summarize a document related to AI?';
      LQueries[16] := 'Retrieve documents discussing AI-related topics';

      // Set column widths for table formatting
      LQueryColWidth := 45;  // Adjust based on longest query
      LRankColWidth := 6;
      LDocColWidth := 10;
      LScoreColWidth := 10;
      LLineWidth := LQueryColWidth + LRankColWidth + LDocColWidth + LScoreColWidth + 10;

      // Print Table Header
      soConsole.PrintLn(StringOfChar('-', LLineWidth));
      soConsole.PrintLn(Format('| %-*s | %-*s | %-*s | %-*s |',
        [LQueryColWidth, 'Query', LRankColWidth, 'Rank', LDocColWidth, 'Document', LScoreColWidth, 'Score']));
      soConsole.PrintLn(StringOfChar('-', LLineWidth));

      // Execute each test query and display the results
      for I := 0 to High(LQueries) do
      begin
        // Search the vector database for the top 3 most relevant documents
        LSearchResults := LVectorDB.Search(LQueries[I], 1);

        if Assigned(LSearchResults) then
        begin
          for J := 0 to LSearchResults.Count - 1 do
          begin
            // Extract document ID and similarity score from the search result
            LSearchResultObj := LSearchResults.Items[J] as TJSONObject;
            LDocID := LSearchResultObj.GetValue('id').Value;
            LScore := (LSearchResultObj.GetValue('score') as TJSONNumber).AsDouble;

            // Print formatted table row
            soConsole.PrintLn(Format('| %-*s | %-*d | %-*s | %-*.6f |',
              [LQueryColWidth, LQueries[I], LRankColWidth, J + 1, LDocColWidth, LDocID, LScoreColWidth, LScore]));
          end;

          // Free the search result JSON array after processing
          LSearchResults.Free();
        end;

        // Print table row separator after processing each query
        soConsole.PrintLn(StringOfChar('-', LLineWidth));
      end;

    finally
      // Close/Free vector database
      LVectorDB.Free();
    end;
  finally
    // Close/Free embeddings engine
    LEmb.Free();
  end;
end;


{
  This example demonstrates how to use web search for retrieving real-time,
  up-to-date information. It utilizes the `TsoWebSearch` class to perform
  a live query and fetch the latest data from the web.

  The procedure performs the following steps:
  1. Initializes the web search engine.
  2. Defines a query to search.
  3. Sends the query to the web search engine.
  4. Displays the response if successful; otherwise, prints an error message.

  NOTE: You have your Tavily account set up, obtained a search API key, and
        set up and assign the search key environment variable,
        "TAVILY_API_KEY".
}
procedure Test06();
var
  // Web search engine for real-time information retrieval
  LWebSearch: TsoWebSearch;

  // The question to be searched on the web
  LQuestion: string;
begin
  // Set the console title for the search test
  soConsole.SetTitle('Sophora: WebSearch');

  // Create an instance of the web search component
  LWebSearch := TsoWebSearch.Create();

  try
    // Define the search query
    //LQuestion := 'What is Bill Gates'' current net worth as of 2025?';
    LQuestion := 'What is the current U.S. national debt as of 2025?';

    // Print the query in cyan for visibility
    soConsole.PrintLn('Query:');
    soConsole.PrintLn(soCSIFGCyan + LQuestion);

    // Print a separator before displaying the web search response
    soConsole.PrintLn();
    soConsole.PrintLn('Web search response:');

    // Execute the web search query and check for success
    if LWebSearch.Query(LQuestion) then
    begin
      // Print the response in green if the search is successful
      soConsole.PrintLn(soCSIFGGreen + soConsole.WrapTextEx(LWebSearch.Response(), 120-10));
    end
    else
    begin
      // Print the error message in red if the search fails
      soConsole.PrintLn(soCSIFGRed + LWebSearch.GetError());
    end;

  finally
    // Free the allocated web search object to prevent memory leaks
    LWebSearch.Free();
  end;
end;


{
  This procedure serves as a test harness for running different test cases
  related to the Large Language Model (LLM) functionalities, such as
  non-thinking mode, deep-thinking mode, and embedding generation.

  The selected test is executed based on a predefined integer value, and the
  console output is formatted to clearly indicate which test is running.
}
procedure RunTests();
var
  // Holds the test number to execute
  LNum: Integer;
begin
  // Print the Sophora version in magenta for visibility
  soConsole.PrintLn(soCSIFGMagenta + 'Sophora v%s' + soCRLF, [CsoSophoraVersion]);

  // Set the test number to execute
  LNum := 01;

  // Execute the corresponding test based on the selected test number
  case LNum of
    01: Test01();  // Runs the non-thinking mode test
    02: Test02();  // Runs the deep-thinking mode test
    03: Test03();  // Runs the embedding generation test
    04: Test04();  // Runs the sqlite database test
    05: Test05();  // Runs the vector database test
    06: Test06();  // Runes the web search test
  end;

  // Pause execution to allow viewing the console output before exiting
  soConsole.Pause();
end;


end.
