#!/bin/bash

# Prompt user to choose between percentage or amount
read -p "Do you want to allocate by percentage or amount? (p/a): " pa_choice

while [[ ! $pa_choice =~ ^[pa]$ ]]; do
  read -p "Please enter 'p' for percentage or 'a' for amount: " pa_choice
done

if [[ $pa_choice == "p" ]]; then
  # Prompt for percentage allocation for each category
  read -p "Enter your salary: " salary

  echo "Salary: $salary"

  # Set arrays to store percentages, amounts, and category names
  percentages=()
  amounts=()
  categories=()

  # Prompt for percentage allocations and category names
  total_percent=0
  while [[ $total_percent -lt 100 ]]; do
    # Calculate percentage remaining
    percent_remaining=$((100 - total_percent))

    read -p "Enter the percentage allocation for a category ($percent_remaining% remaining, 0 to end): " percent

    if [[ $percent -eq 0 ]]; then
      echo "Category allocation complete."
      break
    fi

    total_percent=$((total_percent + percent))

    if [[ $total_percent -gt 100 ]]; then
      echo "Total percentage exceeds $percent_remaining% . Try again."
      total_percent=$((total_percent - percent))
      continue
    fi

    amount=$((salary * percent / 100))

    # Prompt for category name
    read -p "Enter the name for this category: " category_name

    # Add percentage, amount, and category name to arrays
    percentages+=($percent)
    amounts+=($amount)
    categories+=("$category_name")

    echo "  $percent% = $amount"
  done
elif [[ $pa_choice == "a" ]]; then
  # Prompt for amount allocation for each category
  read -p "Enter your salary: " salary

  echo "Salary: $salary"

  # Set arrays to store percentages, amounts, and category names
  percentages=()
  amounts=()
  categories=()

  # Prompt for amount allocations and category names
  total_amount=0
  while [[ $total_amount -lt $salary ]]; do
    # Calculate amount remaining
    amount_remaining=$((salary - total_amount))

    read -p "Enter the amount allocation for a category (€$amount_remaining remaining, 0 to end): " amount

    if [[ $amount -eq 0 ]]; then
      echo "Category allocation complete."
      break
    fi

    total_amount=$((total_amount + amount))

    if [[ $total_amount -gt $salary ]]; then
      echo "Total amount exceeds salary. Try again."
      total_amount=$((total_amount - amount))
      continue
    fi

    percent=$((amount * 100 / salary))

    # Prompt for category name
    read -p "Enter the name for this category: " category_name

    # Add percentage, amount, and category name to arrays
    percentages+=($percent)
    amounts+=($amount)
    categories+=("$category_name")

    echo "  $percent% = $amount"
  done
fi

# Display summary of percentage and money allocated to each category
echo ""
echo "Summary:"
# printf "+----------------+------------+------------+\n"
# printf "| %-14s | %-10s | %-10s |\n" "Category" "Percentage" "Amount"
# printf "+----------------+------------+------------+\n"

# Calculate maximum length of category string
max_length=0
for category in "${categories[@]}"; do
  length=${#category}
  if ((length > max_length)); then
    max_length=$length
  fi
done

# Define column widths based on the maximum category length
category_width=$((max_length + 4))  # Add extra space for padding
percentage_width=10
amount_width=10

# Print table header
printf "|%-${category_width}s +%-${percentage_width}s +%-${amount_width}s |\n" \
  "$(printf -- '-%.0s' $(seq 1 $category_width))" \
  "$(printf -- '-%.0s' $(seq 1 $percentage_width))" \
  "$(printf -- '-%.0s' $(seq 1 $amount_width))"
  printf "|%-${category_width}s | %-${percentage_width}s |%-${amount_width}s |\n" \
  "Category" "Percentage" "Amount"
printf "|%-${category_width}s +%-${percentage_width}s +%-${amount_width}s |\n" \
  "$(printf -- '-%.0s' $(seq 1 $category_width))" \
  "$(printf -- '-%.0s' $(seq 1 $percentage_width))" \
  "$(printf -- '-%.0s' $(seq 1 $amount_width))"

# Print table rows
for i in "${!categories[@]}"; do
  printf "| %-*s | %-*s | $%-*s |\n" \
    "$category_width" "${categories[$i]}" \
    "$percentage_width" "${percentages[$i]}%" \
    "$amount_width" "${amounts[$i]}"
done

# Calculate remaining percentage and amount
remaining_percent=$((100 - total_percent))
remaining_amount=$((salary - total_amount))

printf "|%-${category_width}s +%-${percentage_width}s +%-${amount_width}s |\n" \
  "$(printf -- '-%.0s' $(seq 1 $category_width))" \
  "$(printf -- '-%.0s' $(seq 1 $percentage_width))" \
  "$(printf -- '-%.0s' $(seq 1 $amount_width))"
printf "| %-*s | %-*s | $%-*s |\n" \
  "$category_width" "Remaining" \
  "$percentage_width" "${remaining_percent}%" \
  "$amount_width" "${remaining_amount}"
printf "+%-${category_width}s +%-${percentage_width}s +%-${amount_width}s +\n" \
  "$(printf -- '-%.0s' $(seq 1 $category_width))" \
  "$(printf -- '-%.0s' $(seq 1 $percentage_width))" \
  "$(printf -- '-%.0s' $(seq 1 $amount_width))"

# Prompt user to save the allocation summary to a text file
read -p "Do you want to save the allocation summary to a text file? (y/n) " save_choice

if [[ $save_choice == "y" ]]; then
  read -p "Enter the file name: " filename

  # Write summary to text file
  echo "Summary:" > "$filename"
  printf "|%-${category_width}s +%-${percentage_width}s +%-${amount_width}s |\n" \
    "Category" "Percentage" "Amount" >> "$filename"
  printf "|%-${category_width}s +%-${percentage_width}s +%-${amount_width}s |\n" \
    "$(printf -- '-%.0s' $(seq 1 $category_width))" \
    "$(printf -- '-%.0s' $(seq 1 $percentage_width))" \
    "$(printf -- '-%.0s' $(seq 1 $amount_width))" >> "$filename"

  for i in "${!categories[@]}"; do
    printf "| %-*s | %-*s | $%-*s |\n" \
      "$category_width" "${categories[$i]}" \
      "$percentage_width" "${percentages[$i]}%" \
      "$amount_width" "${amounts[$i]}" >> "$filename"
  done

  printf "|%-${category_width}s +%-${percentage_width}s +%-${amount_width}s |\n" \
    "$(printf -- '-%.0s' $(seq 1 $category_width))" \
    "$(printf -- '-%.0s' $(seq 1 $percentage_width))" \
    "$(printf -- '-%.0s' $(seq 1 $amount_width))" >> "$filename"
  printf "| %-*s | %-*s | $%-*s |\n" \
    "$category_width" "Remaining" \
    "$percentage_width" "${remaining_percent}%" \
    "$amount_width" "${remaining_amount}" >> "$filename"
  printf "+%-${category_width}s +%-${percentage_width}s +%-${amount_width}s +\n" \
    "$(printf -- '-%.0s' $(seq 1 $category_width))" \
    "$(printf -- '-%.0s' $(seq 1 $percentage_width))" \
    "$(printf -- '-%.0s' $(seq 1 $amount_width))" >> "$filename"

  echo "Allocation summary saved to '$filename'."
else
  echo "Allocation summary not saved."
fi
