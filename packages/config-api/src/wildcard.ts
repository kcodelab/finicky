export function matchWildcard(pattern: string, str: string): boolean {
  try {
    if (!pattern.includes("*")) {
      return pattern === str;
    }

    // First handle escaped asterisks by temporarily replacing them
    const ESCAPED_ASTERISK_PLACEHOLDER = "\u0000";
    const LEADING_SUBDOMAIN_PLACEHOLDER = "\u0001";
    let normalizedPattern = pattern.replace(
      /\\\*/g,
      ESCAPED_ASTERISK_PLACEHOLDER
    );
    if (normalizedPattern.startsWith("*.")) {
      normalizedPattern = LEADING_SUBDOMAIN_PLACEHOLDER + normalizedPattern.slice(2);
    }

    // Then escape all special regex chars except asterisk
    let escaped = normalizedPattern.replace(
      /[.+?^${}()|[\]\\]/g,
      "\\$&"
    );

    // If pattern doesn't start with a protocol, make it match common protocols
    const isHostOnlyPattern =
      !/^\w+:/.test(pattern) &&
      !pattern.includes("/") &&
      !pattern.includes("?") &&
      !pattern.includes("#");

    if (!/^\w+:/.test(pattern)) {
      escaped = `(?:https?:|ftp:|mailto:|file:|tel:|sms:|data:)?(?:\/\/)?${escaped}`;
    } else {
      // If it's a protocol pattern, make sure to escape the forward slashes
      escaped = escaped.replace(/\//g, "\\/");
      // If it ends with //, make it match anything after
      if (escaped.endsWith("\\/\\/")) {
        escaped += ".*";
      }
    }

    // Replace unescaped asterisks with non-greedy match to prevent over-matching
    const regexPattern = escaped.replace(/\*/g, ".*?");

    // Finally, restore the escaped asterisks as literal asterisks
    const finalPattern = regexPattern.replace(
      new RegExp(ESCAPED_ASTERISK_PLACEHOLDER, "g"),
      "\\*"
    )
      .replace(new RegExp(LEADING_SUBDOMAIN_PLACEHOLDER, "g"), "(?:.*?\\.)?");

    const pathSuffix = isHostOnlyPattern ? "(?:\\/.*)?" : "";

    // Add start and end anchors to ensure full string match
    const regex = new RegExp(`^${finalPattern}${pathSuffix}$`);

    return regex.test(str);
  } catch (error) {
    console.warn("Invalid wildcard pattern:", pattern, error);
    return false;
  }
}
