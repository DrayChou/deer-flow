import json
from typing import Dict, List, Optional, Tuple, Union, Any

from langchain.callbacks.manager import (
    AsyncCallbackManagerForToolRun,
    CallbackManagerForToolRun,
)
from langchain.tools import BaseTool
from pydantic import Field

from src.tools.searxng_search.searxng_search_api_wrapper import SearXNGSearchAPIWrapper


class SearXNGSearchResults(BaseTool):
    """Tool that queries the SearXNG Search API and gets back results.

    Setup:
        Set environment variable ``SEARXNG_URL`` to your SearXNG instance URL.

    Instantiate:

        .. code-block:: python

            from src.tools.searxng_search import SearXNGSearchResults

            tool = SearXNGSearchResults(
                max_results=5,
                include_images=True,
                language="all",
                categories=["general"],
            )
    """

    name: str = "searxng_search"
    description: str = (
        "A search tool that uses SearXNG to search the web for information. "
        "Input should be a search query."
    )
    
    api_wrapper: SearXNGSearchAPIWrapper = Field(default_factory=SearXNGSearchAPIWrapper)
    max_results: int = 5
    language: str = "all"
    categories: Optional[List[str]] = None
    engines: Optional[List[str]] = None
    include_images: bool = False

    def _run(
        self,
        query: str,
        run_manager: Optional[CallbackManagerForToolRun] = None,
    ) -> Tuple[Union[List[Dict[str, Any]], str], Dict]:
        """Use the tool."""
        try:
            raw_results = self.api_wrapper.raw_results(
                query,
                self.max_results,
                self.language,
                self.categories,
                self.engines,
                include_images=self.include_images,
            )
        except Exception as e:
            return repr(e), {}
        
        cleaned_results = self.api_wrapper.clean_results_with_images(raw_results)
        print("sync", json.dumps(cleaned_results, indent=2, ensure_ascii=False))
        return cleaned_results, raw_results

    async def _arun(
        self,
        query: str,
        run_manager: Optional[AsyncCallbackManagerForToolRun] = None,
    ) -> Tuple[Union[List[Dict[str, Any]], str], Dict]:
        """Use the tool asynchronously."""
        try:
            raw_results = await self.api_wrapper.raw_results_async(
                query,
                self.max_results,
                self.language,
                self.categories,
                self.engines,
                include_images=self.include_images,
            )
        except Exception as e:
            return repr(e), {}
        
        cleaned_results = self.api_wrapper.clean_results_with_images(raw_results)
        print("async", json.dumps(cleaned_results, indent=2, ensure_ascii=False))
        return cleaned_results, raw_results
