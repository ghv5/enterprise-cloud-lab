package lab.enterprise.blog.api;

import java.util.Map;

public record ApiResponse<T>(boolean success, T data, Map<String, ?> meta) {

  public static <T> ApiResponse<T> success(T data, Map<String, ?> meta) {
    return new ApiResponse<>(true, data, Map.copyOf(meta));
  }
}
