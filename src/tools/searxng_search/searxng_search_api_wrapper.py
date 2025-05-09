import json
import os
from typing import Dict, List, Optional, Any

import aiohttp
import requests
from pydantic import BaseModel, Field, SecretStr

class SearXNGSearchAPIWrapper(BaseModel):
    """Wrapper for SearXNG Search API."""

    searxng_url: SecretStr = Field(default_factory=lambda: SecretStr(os.getenv("SEARXNG_URL", "")))
    timeout: int = 10
    
    def raw_results(
        self,
        query: str,
        max_results: Optional[int] = 5,
        language: Optional[str] = "all",
        categories: Optional[List[str]] = None,
        engines: Optional[List[str]] = None,
        format: str = "json",
        include_images: Optional[bool] = False,
    ) -> Dict[str, Any]:
        """Get results from SearXNG."""
        if not self.searxng_url.get_secret_value():
            raise ValueError("SearXNG URL not set.")
            
        params = {
            "q": query,
            "format": format,
            "pageno": 1,
            "count": max_results,
            "language": language,
        }
        
        if categories:
            params["categories"] = ",".join(categories)
            
        if engines:
            params["engines"] = ",".join(engines)
            
        if include_images:
            # If images are requested, add image engines if engines aren't specified
            if not engines:
                image_engines = ["qwant images", "duckduckgo images", "bing images"]
                all_engines = params.get("engines", "").split(",") if params.get("engines") else []
                all_engines.extend(image_engines)
                params["engines"] = ",".join(filter(None, all_engines))
        
        response = requests.get(
            self.searxng_url.get_secret_value(), 
            params=params, 
            timeout=self.timeout
        )
        response.raise_for_status()
        return response.json()

    async def raw_results_async(
        self,
        query: str,
        max_results: Optional[int] = 5,
        language: Optional[str] = "all",
        categories: Optional[List[str]] = None,
        engines: Optional[List[str]] = None,
        format: str = "json",
        include_images: Optional[bool] = False,
    ) -> Dict[str, Any]:
        """Get results from SearXNG asynchronously."""
        if not self.searxng_url.get_secret_value():
            raise ValueError("SearXNG URL not set.")
            
        params = {
            "q": query,
            "format": format,
            "pageno": 1,
            "count": max_results,
            "language": language,
        }
        
        if categories:
            params["categories"] = ",".join(categories)
            
        if engines:
            params["engines"] = ",".join(engines)
            
        if include_images:
            if not engines:
                image_engines = ["qwant images", "duckduckgo images", "bing images"]
                all_engines = params.get("engines", "").split(",") if params.get("engines") else []
                all_engines.extend(image_engines)
                params["engines"] = ",".join(filter(None, all_engines))
                
        async with aiohttp.ClientSession() as session:
            async with session.get(
                self.searxng_url.get_secret_value(), 
                params=params, 
                timeout=self.timeout
            ) as res:
                if res.status == 200:
                    data = await res.text()
                    return json.loads(data)
                else:
                    raise Exception(f"Error {res.status}: {res.reason}")

    def clean_results_with_images(self, raw_results: Dict[str, Any]) -> List[Dict]:
        """Clean results from SearXNG API."""
        clean_results = []
        
        # Process regular search results
        for result in raw_results.get("results", []):
            clean_result = {
                "type": "page",
                "title": result.get("title", ""),
                "url": result.get("url", ""),
                "content": result.get("content", ""),
                "score": result.get("score", 0),
                "engine": result.get("engine", ""),
                "parsed_url": result.get("parsed_url", {})
            }
            clean_results.append(clean_result)
        
        # Process image results
        for image in raw_results.get("images", []):
            clean_result = {
                "type": "image",
                "image_url": image.get("img_src", ""),
                "image_description": image.get("title", ""),
                "source_url": image.get("source", "") or image.get("url", ""),
                "engine": image.get("engine", "")
            }
            clean_results.append(clean_result)
            
        return clean_results


if __name__ == "__main__":
    wrapper = SearXNGSearchAPIWrapper()
    results = wrapper.raw_results("cute pandas", include_images=True)
    print(json.dumps(results, indent=2, ensure_ascii=False))
    clean_results = wrapper.clean_results_with_images(results)
    print(json.dumps(clean_results, indent=2, ensure_ascii=False))
