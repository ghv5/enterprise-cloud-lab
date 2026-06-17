package lab.enterprise.order.controller;

import lab.enterprise.platform.common.core.api.ApiResponse;
import java.math.BigDecimal;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/orders")
public class OrderController {

    @GetMapping("/{id}")
    public ApiResponse<Map<String, Object>> getOrder(@PathVariable Long id) {
        return ApiResponse.ok(Map.of(
            "id", id,
            "amount", BigDecimal.valueOf(128.88),
            "status", "CREATED"
        ));
    }
}
