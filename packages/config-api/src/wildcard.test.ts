import { describe, it, expect } from "vitest";
import { matchWildcard } from "./wildcard";

describe("matchWildcard", () => {
  describe("basic wildcard matching", () => {
    it("matches example.com* pattern with various protocols", () => {
      const pattern = "example.com*";
      expect(matchWildcard(pattern, "https://example.com")).toBe(true);
      expect(matchWildcard(pattern, "http://example.com")).toBe(true);
      expect(matchWildcard(pattern, "mailto:example.com")).toBe(true);
      expect(matchWildcard(pattern, "ftp://example.com")).toBe(true);
      expect(matchWildcard(pattern, "https://example.com/path")).toBe(true);
      expect(matchWildcard(pattern, "https://example.com?query=123")).toBe(
        true
      );
      expect(matchWildcard(pattern, "https://example.com#fragment")).toBe(true);
    });

    it("does not match non-matching domains", () => {
      const pattern = "example.com*";
      expect(matchWildcard(pattern, "https://notexample.com")).toBe(false);
      expect(matchWildcard(pattern, "https://sub.different.com")).toBe(false);
    });
  });

  describe("wildcard positions", () => {
    it("matches wildcards at the start", () => {
      const pattern = "*.example.com";
      expect(matchWildcard(pattern, "https://example.com")).toBe(true);
      expect(matchWildcard(pattern, "https://sub.example.com")).toBe(true);
      expect(matchWildcard(pattern, "https://another.sub.example.com")).toBe(
        true
      );
    });

    it("matches wildcards in the middle", () => {
      const pattern = "example.*/path";
      expect(matchWildcard(pattern, "https://example.com/path")).toBe(true);
      expect(matchWildcard(pattern, "https://example.org/path")).toBe(true);
      expect(matchWildcard(pattern, "https://example.com/other")).toBe(false);
    });

    it("matches multiple wildcards", () => {
      const pattern = "*.example.*/path/*";
      expect(matchWildcard(pattern, "https://sub.example.com/path/test")).toBe(
        true
      );
      expect(
        matchWildcard(pattern, "https://sub.example.org/path/foo/bar")
      ).toBe(true);
      expect(matchWildcard(pattern, "https://sub.example.com/other/test")).toBe(
        false
      );
    });
  });

  describe("escaped wildcards", () => {
    it("matches literal asterisks when escaped", () => {
      const pattern = "example\\*.com";
      expect(matchWildcard(pattern, "https://example*.com")).toBe(true);
      expect(matchWildcard(pattern, "https://example.com")).toBe(false);
    });

    it("combines escaped and unescaped wildcards", () => {
      const pattern = "*example\\*.com/*";
      expect(matchWildcard(pattern, "https://test.example*.com/path")).toBe(
        true
      );
      expect(matchWildcard(pattern, "https://example*.com/anything")).toBe(
        true
      );
      expect(matchWildcard(pattern, "https://example.com/path")).toBe(false);
    });
  });

  describe("special cases", () => {
    it("handles patterns with special regex characters", () => {
      const pattern = "example.com/path?*";
      expect(matchWildcard(pattern, "https://example.com/path?query=123")).toBe(
        true
      );
      expect(matchWildcard(pattern, "https://example.com/path")).toBe(false);
    });

    it("handles full URLs with query parameters and fragments", () => {
      const pattern = "*.com/*#*";
      expect(matchWildcard(pattern, "https://example.com/path#fragment")).toBe(
        true
      );
      expect(
        matchWildcard(
          pattern,
          "https://sub.example.com/path?query=123#fragment"
        )
      ).toBe(true);
    });

    it("handles invalid patterns gracefully", () => {
      const pattern = "[invalid.pattern";
      expect(matchWildcard(pattern, "https://example.com")).toBe(false);
    });
  });

  describe("additional edge cases", () => {
    it("handles exact matches", () => {
      const pattern = "https://example.com";
      expect(matchWildcard(pattern, "https://example.com")).toBe(true);
      expect(matchWildcard(pattern, "http://example.com")).toBe(false);
    });

    it("handles multiple TLD wildcards", () => {
      const pattern = "*.google.*";
      expect(matchWildcard(pattern, "https://mail.google.com")).toBe(true);
      expect(matchWildcard(pattern, "https://docs.google.co.uk")).toBe(true);
      expect(matchWildcard(pattern, "https://google.com")).toBe(true);
    });

    it("handles complex subdomain patterns", () => {
      const pattern = "https://*.github.io/*";
      expect(matchWildcard(pattern, "https://user1.github.io/repo")).toBe(true);
      expect(matchWildcard(pattern, "https://org.github.io/docs/api")).toBe(
        true
      );
      expect(matchWildcard(pattern, "https://github.io/test")).toBe(false);
    });
  });

  describe("domain matching behavior", () => {
    it("matches root and subdomains for wildcard domain", () => {
      const pattern = "*.feishu.cn";
      expect(matchWildcard(pattern, "https://feishu.cn")).toBe(true);
      expect(matchWildcard(pattern, "https://feishu.cn/")).toBe(true);
      expect(matchWildcard(pattern, "https://www.feishu.cn")).toBe(true);
      expect(matchWildcard(pattern, "https://www.feishu.cn/")).toBe(true);
      expect(matchWildcard(pattern, "https://open.feishu.cn")).toBe(true);
      expect(matchWildcard(pattern, "https://a.b.feishu.cn")).toBe(true);
      expect(matchWildcard(pattern, "https://a.b.feishu.cn/path?q=1")).toBe(true);
      expect(matchWildcard(pattern, "https://feishu.com")).toBe(false);
    });
  });
});
