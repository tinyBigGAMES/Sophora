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
   - https://huggingface.co/tinybiggames/DeepHermes-3-Llama-3-8B-Preview-abliterated-Q4_K_M-GGUF/resolve/main/deephermes-3-llama-3-8b-preview-abliterated-q4_k_m.gguf?download=true
   - https://huggingface.co/tinybiggames/bge-m3-Q8_0-GGUF/resolve/main/bge-m3-q8_0.gguf?download=true
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
  System.IOUtils,
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
  // Path to the directory where the LLM model (GGUF format) is stored
  CModelPath        = 'C:/LLM/GGUF';

  // Filename of the prompt database used for structured AI prompts
  CPromptDbFilename = 'prompts.txt';

  // Identifier for the "DeepThink" prompt within the prompt database
  CPromptDeepThink  = 'DeepThink';

  // Maximum context size for the LLM (8K tokens)
  CMaxContext       = 1024 * 8;

  // Toggle show "thinking" tokens on/off
  CShowThinking = True;

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
    LMsg.Add(soUser, 'who is bill gates? (very detailed)');

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

  The function performs the following steps:
  1. Initializes a message queue, inference engine, and prompt database.
  2. Loads the LLM model and retrieves a predefined "DeepThink" prompt.
  3. Provides structured reasoning instructions to the model.
  4. Processes a complex user query.
  5. Displays the AI's reasoning process and final response.
  6. Outputs performance metrics, including input tokens, output tokens, and
     processing speed.

  This approach is useful for applications requiring in-depth AI reasoning and
  systematic thought processing.
}

procedure Test02();
var
  // Stores the messages exchanged between the user and LLM
  LMsg: TsoMessages;

  // Represents the inference engine responsible for running the LLM
  LInf: TsoInference;

  // Holds the count of input tokens processed by the model
  LInputTokens: Integer;

  // Holds the count of output tokens generated by the model
  LOutputTokens: Integer;

  // Represents the speed of token generation (tokens per second)
  LTokenSpeed: Single;

  // Database for managing reusable AI prompts
  LPrompts: TsoPromptDatabase;

  // Stores the retrieved prompt from the database
  LPrompt: TsoPrompt;
begin
  // Set the console title for the test
  soConsole.SetTitle('Sophora: Thinking Mode');

  // Create instances of message handler, inference engine, and prompt database
  LMsg := TsoMessages.Create();
  LInf := TsoInference.Create();
  LPrompts := TsoPromptDatabase.Create();

  try
    // Set the model path before loading
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

    // Load prompts from the file; exit if loading fails
    if not LPrompts.LoadFromFile(CPromptDbFilename) then Exit;

    // Retrieve the "DeepThink" prompt; exit if not found
    if not LPrompts.GetPrompt(CPromptDeepThink, LPrompt) then Exit;

    // Provide a system instruction that enables deep reasoning mode
    LMsg.Add(soSystem, LPrompt.Prompt);

    // Add a complex user query to be analyzed in deep thinking mode
    LMsg.Add(soUser, 'I walk on four legs in the morning, two legs at noon, and three legs in the evening. ' +
                      'But beware, for this is not the famous riddle of the Sphinx. Instead, my journey is cyclical, ' +
                      'and each stage is both an end and a beginning. I am not a creature, but I hold the essence of ' +
                      'all creatures within me. What am I?');

    // Print the user question with formatting
    soConsole.PrintLn('Question: %s%s' + soCRLF,
      [soCSIFGCyan + soCRLF, soConsole.WrapTextEx(LMsg.LastUser(), 120 - 10)]);

    // Print response header
    soConsole.PrintLn('Response:');

    // Execute inference with the provided user query
    if LInf.Run(LMsg, CMaxContext) then
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
    if Assigned(LPrompts) then LPrompts.Free();
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

  // Create an instance of the web search class
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
  This example demonstrates how to use the prompt database in Sophora to retrieve predefined prompts.
  The procedure performs the following steps:

  1. Initializes the prompt database class.
  2. Loads a list of prompts from a text file (`prompts.txt`).
  3. Retrieves a specific prompt using its unique ID (`DeepThink`).
  4. Displays the prompt's ID, description, and content with formatted output.

  This functionality is useful for managing reusable prompts in AI applications.
}
procedure Test07();
const
  // The ID of the prompt to retrieve from the database
  CPromptID = 'DeepThink';
var
  // Object for handling the prompt database
  LPromptDb: TsoPromptDatabase;

  // Object to store the retrieved prompt data
  LPrompt: TsoPrompt;
begin
  // Set the console title for the prompt database test
  soConsole.SetTitle('Sophora: Prompt Database');

  // Create an instance of the prompt database
  LPromptDb := TsoPromptDatabase.Create();

  try
    // Load prompts from the specified file; proceed only if successful
    if LPromptDb.LoadFromFile('prompts.txt') then
    begin
      // Retrieve the prompt with the specified ID
      if LPromptDb.GetPrompt(CPromptID, LPrompt) then
      begin
        // Print the prompt details in green for readability
        soConsole.PrintLn('ID         : %s%s', [soCSIFGGreen, LPrompt.ID]);
        soConsole.PrintLn('Description: %s%s', [soCSIFGGreen, LPrompt.Description]);
        soConsole.PrintLn('Prompt     : ' + soCRLF + soCSIFGGreen + '%s',
          [soConsole.WrapTextEx(LPrompt.Prompt, 120-10)]);
      end;
    end;
  finally
    // Free allocated resources to prevent memory leaks
    LPromptDb.Free();
  end;
end;

var
  // Global instance of the tool management system
  LTools: TsoTools;

type
  // Tools static class
  {$M+}
  MyTools = class
  published
    // Document the tool method
    [soSchemaDescription('Provides access to the internet to perform a web search and return the answer as a string. Only call when you can not answer the query and for real-time, time sensitive information')]
    class function web_search(
      // Document the tool method params
      [soSchemaDescription('A string containing the result of the search query')]
       query: string
    ): string; static;
  end;
  {$M-}

// Websearch tool function
class function MyTools.web_search(query: string): string;
begin
  Result := LTools.WebSearch(query.Trim()).Trim();
end;

{
  This example demonstrates how to integrate tool-based reasoning with
  DeepHermes-3, leveraging web search for real-time information retrieval and
  processing.

  The procedure performs the following steps:
  1. Loads a predefined prompt database.
  2. Creates an instance of `TsoTools` to manage external tool calls.
  3. Defines a `web_search` tool function that:
     - Receives queries as function call parameters.
     - Performs a web search using `ATools.CallTool()`.
     - Formats the retrieved response into an LLM-compatible message.
     - Passes the result back into the LLM for further processing.
  4. Constructs a message sequence with a system prompt.
  5. Calls the inference engine (`TsoInference`) to process the request.
  6. Displays the LLM-generated response and performance metrics.

  This implementation is useful for Retrieval-Augmented Generation (RAG) and
  AI-assisted real-time fact-checking.

  NOTE: You must have your Tavily account setup and the TAVILY_API_KEY
  environment variable defined.
}

procedure Test08();
var
  // Object to manage predefined prompts
  LPromptDB: TsoPromptDatabase;

  // Holds a retrieved prompt
  LPrompt: TsoPrompt;

  // Message queue for communication with the LLM
  LMsg: TsoMessages;

  // Inference engine instance
  LInf: TsoInference;

  // Performance tracking variables
  LTokenSpeed: Single;
  LInputTokens, LOutputTokens: Integer;
begin
  // Set the console title for the tool call test
  soConsole.SetTitle('Sophora: Tool Call');


  // Create an instance of the prompt database
  LPromptDB := TsoPromptDatabase.Create();

  try
    // Load the prompt database from file; exit if loading fails
    if not LPromptDB.LoadFromFile(CPromptDbFilename) then Exit;

    // Initialize tool management system
    LTools := TsoTools.Create();

    try
      // Associate prompts with the tool system
      LTools.SetPrompts(LPromptDB);

      // Register the "web_search" tool
      LTools.Add(
        MyTools,
        'web_search',

        // Tool function definition
        procedure(const ATools: TsoTools; const AMessages: TsoMessages;
                  const AInference: TsoInference; const AToolCall: TsoToolCall)
        var
          LArgs: TsoParamArg;
          LResponse: string;
        begin
          // Ensure all required objects are assigned
          if not Assigned(ATools) or not Assigned(AMessages) or
             not Assigned(AInference) or not Assigned(AToolCall) then Exit;

          // Print function call information
          soConsole.PrintLn();
          soConsole.PrintLn();
          soConsole.PrintLn(soCSIFGYellow + 'tool_call: "web_search"...');

          // Loop through parameters and perform web search
          for LArgs in AToolCall.Params do
          begin
            // Execute web search and retrieve response
            LResponse := ATools.CallTool(AToolCall.GetClass(), AToolCall.FuncName, [LArgs.Value]).AsString;

            // Clear previous messages
            AMessages.Clear();

            // Retrieve and apply the structured system prompt
            ATools.GetPrompts().GetPrompt(CsoDeepThinkID, LPrompt);
            AMessages.Add(soSystem, LPrompt.Prompt);

            // Add the web search response as a user message
            AMessages.Add(soUser, LResponse);
          end;

          // Run inference on the processed query
          if not AInference.Run(AMessages, CMaxContext) then
          begin
            // If inference fails, print an error message
            soConsole.PrintLn();
            soConsole.PrintLn();
            soConsole.PrintLn(soCSIFGRed + 'Error: %s', [AInference.GetError()]);
          end;
        end
      );

      // Create message queue for inference
      LMsg := TsoMessages.Create();

      try
        // Retrieve the structured system prompt
        LTools.GetPrompts().GetPrompt(CsoDeepThinkID, LPrompt);
        LMsg.Add(soSystem, LPrompt.Prompt);

        // Trigger the tool-based prompt call
        LMsg.Add(soSystem, LTools.CallPrompt());

        // Add a user query that requires real-time information
        LMsg.Add(soUser, 'What is the current U.S. national debt as of 2025?');
        //LMsg.Add(soUser, 'What is Bill Gates''s current net worth as of 2025?');
        //LMsg.Add(soUser, 'lookup about the letter that D.O.G.E department sent to all federal empolyees recently?');
        //LMsg.Add(soUser, 'what is the latest information about the 2025 california fires?');
        //LMsg.Add(soUser, 'what is the latest D.O.G.E information about the 2025?');
        //LMsg.Add(soUser, 'are MAGA supporters regretting their decision to vote for Trump?');
        //LMsg.Add(soUser, 'what is Trump''s current approval rating as of Feburary 2025?');
        //LMsg.Add(soUser, 'how much as Captain America: Brave New World earned at the box officemade at the box office so far?');

        // Create and configure the inference engine
        LInf := TsoInference.Create();

        try

          // Set model path
          LInf.SetModelPath(CModelPath);

          // Define event handlers for token generation
          LInf.NextTokenEvent :=
            procedure (const AToken: string)
            begin
              soConsole.Print(soCSIFGGreen + soCSIBold + soUtils.SanitizeFromJson(AToken));
            end;

          // Define thinking state events
          LInf.ThinkStartEvent :=
            procedure()
            begin
              soConsole.Print(soCSIFGBrightWhite + soCRLF+'Thinking...');
            end;

          LInf.ThinkEndEvent :=
            procedure()
            begin
              soConsole.ClearLine();
              soConsole.PrintLn();
              soConsole.PrintLn(soCSIFGCyan + soUtils.GetRandomThinkingResult());
            end;

          // Enable "thinking" mode if configured
          LInf.ShowThinking := CShowThinking;

          // Load the LLM model; exit if loading fails
          if not LInf.LoadModel() then Exit;

          // Run inference with the given message sequence
          if LInf.Run(LMsg, CMaxContext) then
          begin
            // Execute tool-based processing with the inference results
            LTools.Call(LMsg, LInf, LInf.Response());

            // Display performance metrics
            LInf.Performance(@LInputTokens, @LOutputTokens, @LTokenSpeed);
            soConsole.PrintLn(soCRLF + soCRLF + 'Performance:' + soCRLF +
              soCSIFGYellow + 'Input : %d tokens' + soCRLF +
              'Output: %d tokens' + soCRLF +
              'Speed : %3.2f tokens/sec',
              [LInputTokens, LOutputTokens, LTokenSpeed]);
          end
          else
          begin
            // Print an error message if inference fails
            soConsole.PrintLn();
            soConsole.PrintLn();
            soConsole.PrintLn(soCSIFGRed + 'Error: %s', [LInf.GetError()]);
          end;

        finally
          // Free the inference engine object
          LInf.Free();
        end;
      finally
        // Free the message queue object
        LMsg.Free();
      end;
    finally
      // Free the tool management system
      LTools.Free();
    end;
  finally
    // Free the prompt database object
    LPromptDB.Free();
  end;
end;


{
  This example demonstrates how to use a **large vector database** for **semantic search**
  using DeepHermes-3 embeddings. It performs the following steps:

  1. Initializes the embedding model and vector database.
  2. Checks if the vector database (`deepseek-r1.db`) exists.
  3. If missing, reads `deepseek-r1.txt`, chunks the text, and creates the vector database.
  4. Performs a **semantic search query** against the database.
  5. Displays the top search results as formatted JSON.

  This approach is useful for **Retrieval-Augmented Generation (RAG)** and knowledge-driven
  AI applications.
}
procedure Test09();
var
  // Embedding engine for generating vector representations
  LEmb: TsoEmbeddings;

  // Vector database for storing and retrieving embeddings
  LVec: TsoVectorDatabase;

  // Stores input text for vectorization
  LText: string;

  // Holds the JSON response from the vector search
  LJsonArray: TJSONArray;

  // Flag indicating whether to create and chunk the database
  LChunkDb: Boolean;

  // Query string for semantic search
  LQuery: string;
begin
  // Set the console title for the vector database test
  soConsole.SetTitle('Sophora: Large Vector DB');

  // Create an instance of the embedding engine
  LEmb := TsoEmbeddings.Create();

  try
    // Set the model path before loading
    LEmb.SetModelPath(CModelPath);

    // Load the embedding model with default settings
    if not LEmb.LoadModel(0, 0, csoDefaultEmbeddingsModelFilename) then Exit;

    // Create an instance of the vector database
    LVec := TsoVectorDatabase.Create();

    try
      // Check if the vector database already exists
      LChunkDb := not TFile.Exists('deepseek-r1.db');

      // Open the vector database, linked to the embedding model
      if not LVec.Open(LEmb, 'deepseek-r1.db') then Exit;

      // If the database does not exist, create it from the source text
      if LChunkDb then
      begin
        // Read the content of the source text file
        LText := TFile.ReadAllText('deepseek-r1.txt');

        // If the file is not empty, process the text into vector embeddings
        if not LText.IsEmpty then
        begin
          soConsole.PrintLn(soCSIFGYellow + 'Chunking "deepseek-r1.txt"...');

          // Add the large document to the vector database with chunking (size: 100)
          if LVec.AddLargeDocument('doc-deepseekr1',
             'DeepSeek-R1: Incentivizing Reasoning Capability in LLMs via Reinforcement',
             LText, 200) then
            soConsole.PrintLn(soCSIFGYellow + 'Successfully created "deepseek-r1.db", vector database')
          else
            soConsole.PrintLn(soCSIFGRed + 'Error: %s', [LVec.GetError()]);
        end;
      end;

      // Indicate that semantic search is being performed
      soConsole.PrintLn(soCSIFGYellow + 'Performing semantic search in "deepseek-r1.db"...' + soCRLF);

      // Define a search query
      LQuery := 'What are the key differences between DeepSeek-R1-Zero and DeepSeek-R1?';

      // Alternative queries for experimentation
      // LQuery := 'What reinforcement learning algorithm was used for training DeepSeek-R1-Zero, and how does it work?';
      // LQuery := 'How did majority voting impact DeepSeek-R1-Zero’s performance, and what does this reveal about its reasoning capabilities?';
      // LQuery := 'What are the future research directions for DeepSeek-R1?';
      // LQuery := 'Why did DeepSeek-R1-Zero struggle with readability despite its strong reasoning capabilities?';

      // Print the query for visibility
      soConsole.PrintLn('Query:');
      soConsole.PrintLn(soCSIFGCyan + LQuery + soCRLF);

      // Execute semantic search on the vector database
      LJsonArray := LVec.Search(LQuery, 3);

      // Display JSON search results if available
      if Assigned(LJsonArray) then
      begin
        soConsole.PrintLn('Relevant search results:');
        soConsole.PrintLn(soCSIFGGreen + LJsonArray.Format());

        // Free the JSON array to prevent memory leaks
        LJsonArray.Free();
      end;

    finally
      // Free the vector database object
      LVec.Free();
    end;

  finally
    // Free the embedding engine object
    LEmb.Free();
  end;
end;

{
  This example demonstrates **Advanced Vector Database Search & RAG Processing** using DeepHermes-3.
  It performs the following steps:

  1. **Initialize the Embedding Model & Vector Database**
     - Loads DeepHermes embeddings model.
     - Opens the existing vector database (`deepseek-r1.db`) or creates it if missing.

  2. **Document Chunking & Storage**
     - If `deepseek-r1.db` does not exist, reads `deepseek-r1.txt`.
     - Splits the text into smaller chunks (200 tokens per chunk) and stores it.

  3. **Perform a Semantic Search Query**
     - Retrieves the **top 5 relevant** document chunks using `Search2()`.
     - Uses a high recall setting (1000 tokens, 0.1 similarity threshold, CMaxContext).

  4. **Context Preparation for Retrieval-Augmented Generation (RAG)**
     - Extracts and concatenates retrieved text chunks.
     - Loads structured prompts for processing.

  5. **LLM-Based Reasoning on Retrieved Data**
     - Uses DeepHermes-3 to analyze the retrieved context.
     - Formats the response according to pre-defined system prompts.

  This implementation is crucial for **RAG-powered AI assistants**, providing accurate,
  **contextual retrieval** and reasoning capabilities.
}
procedure Test10();
var
  // Embedding engine for generating vector representations
  LEmb: TsoEmbeddings;

  // Vector database for storing and retrieving embeddings
  LVec: TsoVectorDatabase;

  // Stores input text for vectorization
  LText: string;

  // Holds the retrieved documents from the vector search
  LDocs: TArray<TsoVectorDatabaseDocument>;

  // Flag indicating whether to create and chunk the database
  LChunkDb: Boolean;

  // Query string for semantic search
  LQuery: string;

  // Iterator for document processing
  I: Integer;

  // LLM interaction components
  LMsg: TsoMessages;
  LInf: TsoInference;
  LPromptDB: TsoPromptDatabase;
  LPrompt: TsoPrompt;
begin
  // Set the console title for the vector database test
  soConsole.SetTitle('Sophora: Large Vector DB');

  // Create an instance of the embedding engine
  LEmb := TsoEmbeddings.Create();
  try
    // Set the model path before loading
    LEmb.SetModelPath(CModelPath);

    // Load the embedding model with default settings
    if not LEmb.LoadModel(0, 0, csoDefaultEmbeddingsModelFilename) then Exit;

    // Create an instance of the vector database
    LVec := TsoVectorDatabase.Create();
    try
      // Check if the vector database already exists
      LChunkDb := not TFile.Exists('deepseek-r1.db');

      // Open the vector database, linked to the embedding model
      if not LVec.Open(LEmb, 'deepseek-r1.db') then Exit;

      // If the database does not exist, create it from the source text
      if LChunkDb then
      begin
        // Read the content of the source text file
        LText := TFile.ReadAllText('deepseek-r1.txt');

        // If the file is not empty, process the text into vector embeddings
        if not LText.IsEmpty then
        begin
          soConsole.PrintLn(soCSIFGYellow + 'Chunking "deepseek-r1.txt"...');

          // Add the large document to the vector database with chunking (size: 200 tokens)
          if LVec.AddLargeDocument('doc-deepseekr1',
             'DeepSeek-R1: Incentivizing Reasoning Capability in LLMs via Reinforcement',
             LText, 200) then
            soConsole.PrintLn(soCSIFGYellow + 'Successfully created "deepseek-r1.db", vector database')
          else
            soConsole.PrintLn(soCSIFGRed + 'Error: %s', [LVec.GetError()]);
        end;
      end;

      // Indicate that semantic search is being performed
      soConsole.PrintLn(soCSIFGYellow + 'Performing semantic search in "deepseek-r1.db"...' + soCRLF);

      // Define a search query
      LQuery := 'What are the key differences between DeepSeek-R1-Zero and DeepSeek-R1?';

      // Alternative queries for experimentation
      // LQuery := 'Why did DeepSeek-R1-Zero struggle with readability despite its strong reasoning capabilities?';
      // LQuery := 'What reinforcement learning algorithm was used for training DeepSeek-R1-Zero, and how does it work?';
      // LQuery := 'How did majority voting impact DeepSeek-R1-Zero’s performance, and what does this reveal about its reasoning capabilities?';
      // LQuery := 'How does DeepSeek-R1 perform compared to OpenAI’s o1-1217 model?';
      // LQuery := 'How do DeepSeek-R1 distilled models compare to their RL-trained counterparts?';

      // Print the query for visibility
      soConsole.PrintLn('Query:');
      soConsole.PrintLn(soCSIFGCyan + LQuery + soCRLF);

      // Execute semantic search on the vector database with optimized parameters
      LDocs := LVec.Search2(LQuery, 5, 1000, 0.1, CMaxContext);

      // Prepare retrieved content for LLM processing
      LText := '';
      for I := Low(LDocs) to High(LDocs) do
      begin
        LText := LText + LDocs[I].Text + soCRLF;
      end;
      LText := LText.Trim();

      // Print retrieved documents (for debugging)
      // soConsole.PrintLn(LText);

      // Load the prompt database
      LPromptDB := TsoPromptDatabase.Create();
      try
        if not LPromptDB.LoadFromFile(CPromptDbFilename) then Exit;

        // Create a message queue for LLM processing
        LMsg := TsoMessages.Create();
        try
          // Create the inference engine
          LInf := TsoInference.Create();
          try
            LInf.SetModelPath(CModelPath);
            if not LInf.LoadModel() then Exit;

            // Disable "thinking" animation for speed
            LInf.ShowThinking := False;

            // Retrieve structured reasoning prompt
            LPromptDb.GetPrompt(CsoDeepThinkID, LPrompt);
            LMsg.Add(soSystem, LPrompt.Prompt);

            // Retrieve vector search response template
            LPromptDb.GetPrompt(CsoVectorSearchID, LPrompt);
            LText := Format(LPrompt.Prompt, [LQuery, LText]);

            // Add retrieved search results as a user message
            LMsg.Add(soUser, LText);

            // Execute inference on the retrieved knowledge
            LInf.Run(LMsg);
          finally
            // Free the inference engine
            LInf.Free();
          end;
        finally
          // Free the message queue
          LMsg.Free();
        end;
      finally
        // Free the prompt database
        LPromptDB.Free();
      end;

    finally
      // Free the vector database object
      LVec.Free();
    end;
  finally
    // Free the embedding engine object
    LEmb.Free();
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
  try
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
      06: Test06();  // Runs the web search test
      07: Test07();  // Runs the prompt database test
      08: Test08();  // Runs the tool call with web_search test
      09: Test09();  // Runs the large vector database search test (semantic retrieval)
      10: Test10();  // Runs the advanced RAG-based retrieval test (LLM-enhanced search)
    end;

  except
    on E: Exception do
    begin
      soConsole.PrintLn('Error: %s', [E.Message]);
    end;
  end;

  // Pause execution to allow viewing the console output before exiting
  //soConsole.Pause();

  writeln;
  write('press enter to continue...');
  readln;
  writeln;

end;


end.
