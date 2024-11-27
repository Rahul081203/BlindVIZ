from fastapi import FastAPI
from langchain.prompts import ChatPromptTemplate
from langchain.chat_models import ChatOpenAI
from langserve import add_routes
from langchain_community.llms.ollama import Ollama
import uvicorn
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Set the OpenAI API Key
os.environ["OPENAI_API_KEY"] = os.getenv("OPENAI_API_KEY")

# Initialize FastAPI app
app = FastAPI(
    title="Langchain Server",
    version="1.0",
    description="A simple API Server"
)
# 
openai_model = ChatOpenAI()
# ollama_model = Ollama(model="phi3", num_predict=20, temperature=0.7, num_thread=3, num_gpu=1, keep_alive=-1, top_k=20, top_p=0.8, cache=False, verbose=True)

query_prompt = ChatPromptTemplate.from_template("You are an AI assistant for the blind and visually impaired. The user has entered this query: {query}. Answer accordingly. Be concise when not necessary.")
describe_prompt = ChatPromptTemplate.from_template("{query}")


add_routes(
    app,
    query_prompt | openai_model,
    path="/query"
)

add_routes(
    app,
    describe_prompt | openai_model,
    path="/describe"
)
# Run the server
if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
