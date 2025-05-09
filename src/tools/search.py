# Copyright (c) 2025 Bytedance Ltd. and/or its affiliates
# SPDX-License-Identifier: MIT

import json
import logging
import os

from langchain_community.tools import BraveSearch, DuckDuckGoSearchResults
from langchain_community.tools.arxiv import ArxivQueryRun
from langchain_community.utilities import ArxivAPIWrapper, BraveSearchWrapper

from src.config import SEARCH_MAX_RESULTS
from src.tools.tavily_search.tavily_search_results_with_images import (
    TavilySearchResultsWithImages,
)
from src.tools.searxng_search.searxng_search_results import (
    SearXNGSearchResults,
)

from .decorators import create_logged_tool

logger = logging.getLogger(__name__)


LoggedTavilySearch = create_logged_tool(TavilySearchResultsWithImages)
tavily_search_tool = LoggedTavilySearch(
    name="web_search",
    max_results=SEARCH_MAX_RESULTS,
    include_raw_content=True,
    include_images=True,
    include_image_descriptions=True,
)

LoggedDuckDuckGoSearch = create_logged_tool(DuckDuckGoSearchResults)
duckduckgo_search_tool = LoggedDuckDuckGoSearch(
    name="web_search", max_results=SEARCH_MAX_RESULTS
)

LoggedBraveSearch = create_logged_tool(BraveSearch)
brave_search_tool = LoggedBraveSearch(
    name="web_search",
    search_wrapper=BraveSearchWrapper(
        api_key=os.getenv("BRAVE_SEARCH_API_KEY", ""),
        search_kwargs={"count": SEARCH_MAX_RESULTS},
    ),
)

LoggedArxivSearch = create_logged_tool(ArxivQueryRun)
arxiv_search_tool = LoggedArxivSearch(
    name="web_search",
    api_wrapper=ArxivAPIWrapper(
        top_k_results=SEARCH_MAX_RESULTS,
        load_max_docs=SEARCH_MAX_RESULTS,
        load_all_available_meta=True,
    ),
)

LoggedSearXNGSearch = create_logged_tool(SearXNGSearchResults)
searxng_search_tool = LoggedSearXNGSearch(
    name="web_search",
    max_results=SEARCH_MAX_RESULTS,
    include_images=True,
    language=os.getenv("SEARXNG_LANGUAGE", "all"),
    categories=os.getenv("SEARXNG_CATEGORIES", "").split(",") if os.getenv("SEARXNG_CATEGORIES") else None,
    engines=os.getenv("SEARXNG_ENGINES", "").split(",") if os.getenv("SEARXNG_ENGINES") else None,
)

if __name__ == "__main__":
    results = tavily_search_tool.invoke("cute panda")
    print(json.dumps(results, indent=2, ensure_ascii=False))
    
    # Test SearXNG search
    if os.getenv("SEARXNG_URL"):
        print("\nTesting SearXNG search:")
        results = searxng_search_tool.invoke("cute panda")
        print(json.dumps(results, indent=2, ensure_ascii=False))
