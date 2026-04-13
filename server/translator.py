"""
Translation using Gemini API for Japanese translation of lyrics.
"""
import asyncio
import time
import google.generativeai as genai
from typing import List, Optional
from .config import config

# System prompt for Gemini (defined in prompt ④)
GEMINI_SYSTEM_PROMPT = """あなたは90年代〜2000年代のアメリカン・ヒップホップ（主にEast/West Coast）の歌詞を、日本語の音楽ファン向けに高品質な意訳（翻訳ではなく意訳）する専門家です。

以下の要件に従って翻訳を行ってください：

1. 文化的文脈の理解:
   - AAVE（African American Vernacular English）のスラング・文法を正確に解釈する
   - Nas, 2Pac, Jay-Z, Biggie, Eminem, Wu-Tang Clan 等の表現スタイルを理解する
   - ストリート用語（beef, getting money, ride or die等）を文脈に合った日本語に変換する
   - 聖書・神話・ストリート文化への参照（allusion）を注記せずに意訳に溶け込ませる

2. 翻訳品質:
   - 逐語訳・直訳を避け、日本語として自然でリズム感のある意訳を行う
   - 韻（rhyme）が崩れても、意味の正確さを優先する
   - 性的・暴力的表現も意味を損なわず、日本語として自然な表現に変換する
   - 固有名詞（地名・人名・ブランド等）はそのままカタカナ表記を原則とする

3. 出力形式（厳守）:
   - 入力は番号付きの行リスト（例: "1. It was all a dream"）
   - 出力は同じ番号順の意訳のみをJSONで返す
   - 絶対にマークダウン記法（```等）を使わない
   - 行数は入力と必ず一致させる
   - 意訳不能な行（コーラス記号等）は原文をそのままカタカナで返す
   - 余計な説明・注釈を一切含めない
   
   出力形式:
   {"translations": ["意訳1", "意訳2", "意訳3", ...]}

4. 禁止事項:
   - 「〜でしょう」「〜と思われます」等の推量表現
   - 「原文では〜」等のメタコメント
   - 行の統合・分割（必ず入力と同じ行数を出力）"""

async def translate_lyrics(lines: List[str]) -> List[str]:
    """
    Translate lyrics lines using Gemini API.
    Returns a list of Japanese translations in the same order as input.
    """
    if not config.GEMINI_API_KEY:
        raise ValueError("GEMINI_API_KEY is not configured")
    
    # Configure Gemini
    genai.configure(api_key=config.GEMINI_API_KEY)
    model = genai.GenerativeModel(
        model_name=config.GEMINI_MODEL,
        system_instruction=GEMINI_SYSTEM_PROMPT
    )
    
    # Prepare input as numbered list
    numbered_lines = [f"{i+1}. {line}" for i, line in enumerate(lines)]
    input_text = "\n".join(numbered_lines)
    
    # Retry logic with exponential backoff
    max_retries = 3
    base_delay = 2.0
    
    for attempt in range(max_retries):
        try:
            response = await asyncio.to_thread(
                model.generate_content,
                input_text,
                generation_config=genai.types.GenerationConfig(
                    temperature=0.7,
                    response_mime_type="application/json"
                )
            )
            
            # Parse response
            result_text = response.text.strip()
            
            # Remove markdown code blocks if present
            if result_text.startswith("```"):
                result_text = result_text.split("```")[1]
                if result_text.startswith("json"):
                    result_text = result_text[4:]
            result_text = result_text.strip()
            
            # Parse JSON
            import json
            result = json.loads(result_text)
            
            translations = result.get("translations", [])
            
            # Validate that we have the same number of translations
            if len(translations) != len(lines):
                raise ValueError(f"Translation count mismatch: expected {len(lines)}, got {len(translations)}")
            
            return translations
        
        except Exception as e:
            if attempt == max_retries - 1:
                raise Exception(f"Translation failed after {max_retries} attempts: {e}")
            
            # Exponential backoff
            delay = base_delay * (2 ** attempt)
            await asyncio.sleep(delay)
    
    # Fallback: return empty translations
    return [""] * len(lines)
