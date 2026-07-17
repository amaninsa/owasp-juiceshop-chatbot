from __future__ import annotations

from openai import OpenAI

from config import get_settings
from rag import ProductRetriever

SYSTEM_PROMPT = """You are {assistant_name}, a helpful shopping assistant for OWASP Juice Shop.

Answer questions about products and pricing using ONLY the retrieved product context below.
Be concise, accurate, and friendly.

Rules:
- Always quote prices in USD from the retrieved context.
- Mention deluxe pricing when available and relevant.
- If the context does not contain enough information, say you do not know.
- Do not invent products, discounts, or prices.
- You may compare products, recommend options, and summarize pricing based on retrieved context.

Retrieved product context:
{context}
"""


class ProductAssistant:
    def __init__(self) -> None:
        settings = get_settings()
        self.model = settings.openai_model
        self.client = OpenAI(api_key=settings.open_ai_key)
        self.retriever = ProductRetriever()
        self.assistant_name = settings.assistant_name

    def ask(
        self,
        message: str,
        history: list[dict[str, str]] | None = None,
    ) -> str:
        retrieved = self.retriever.retrieve(message)
        context = self.retriever.format_context(retrieved)
        system_prompt = SYSTEM_PROMPT.format(
            assistant_name=self.assistant_name,
            context=context,
        )

        messages: list[dict[str, str]] = [
            {"role": "system", "content": system_prompt},
        ]
        if history:
            messages.extend(history)
        messages.append({"role": "user", "content": message})

        response = self.client.chat.completions.create(
            model=self.model,
            messages=messages,
            temperature=0.2,
        )
        content = response.choices[0].message.content
        return (content or "").strip()
