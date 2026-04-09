---
domain: financial
pattern: calculation
language: java
framework: spring-boot
agent: claude-sonnet
quality: 0.9
tags: roi, investment, calculation
---

## Prompt

Crie um serviço Spring Boot que calcula o ROI (Return on Investment) 
de um investimento, considerando aportes mensais, taxa de juros variável 
e inflação. O cálculo deve ser feito mês a mês e retornar um DTO com 
o extrato completo.

## Solution

```java
@Service
public class RoiCalculationService {

    public InvestmentReportDTO calculateRoi(InvestmentRequest request) {
        List<MonthlyEntry> entries = new ArrayList<>();
        BigDecimal balance = request.getInitialAmount();
        BigDecimal totalInvested = request.getInitialAmount();
        
        for (int month = 1; month <= request.getMonths(); month++) {
            BigDecimal rate = request.getMonthlyRates().getOrDefault(month, 
                request.getDefaultRate());
            BigDecimal inflation = request.getMonthlyInflation().getOrDefault(month,
                BigDecimal.ZERO);
            
            // Apply monthly return
            BigDecimal monthlyReturn = balance.multiply(rate)
                .setScale(2, RoundingMode.HALF_UP);
            
            // Add monthly contribution
            balance = balance.add(monthlyReturn)
                .add(request.getMonthlyContribution());
            totalInvested = totalInvested.add(request.getMonthlyContribution());
            
            // Adjust for inflation (real return)
            BigDecimal realReturn = monthlyReturn.subtract(
                balance.multiply(inflation).setScale(2, RoundingMode.HALF_UP));
            
            entries.add(MonthlyEntry.builder()
                .month(month)
                .balance(balance)
                .nominalReturn(monthlyReturn)
                .realReturn(realReturn)
                .contribution(request.getMonthlyContribution())
                .build());
        }
        
        BigDecimal totalReturn = balance.subtract(totalInvested);
        BigDecimal roiPercentage = totalReturn.divide(totalInvested, 4, RoundingMode.HALF_UP)
            .multiply(BigDecimal.valueOf(100));
        
        return InvestmentReportDTO.builder()
            .totalInvested(totalInvested)
            .finalBalance(balance)
            .totalReturn(totalReturn)
            .roiPercentage(roiPercentage)
            .entries(entries)
            .build();
    }
}
```

## Summary

Serviço de cálculo ROI com aportes mensais, taxa variável e ajuste inflacionário.
Usa BigDecimal para precisão financeira. Retorna extrato mês a mês com retorno real vs nominal.
