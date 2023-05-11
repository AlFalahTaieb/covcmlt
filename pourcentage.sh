#!/bin/bash

echo "What would you like to calculate? Please choose an option:"
echo "1. Percentage of one number relative to another"
echo "2. Percentage change from one number to another"
echo "3. Tip percentage"
echo "4. Increase or decrease by percentage"
read choice

# Prompt the user for input based on their selected calculation
if [ "$choice" = "1" ]; then
  echo "Enter a number: "
  read num1

  echo "Enter another number: "
  read num2

  # Calculate percentage of num1 relative to num2
  percent=$(echo "scale=2; $num1 / $num2 * 100" | bc)
  echo "$num1 is $percent% of $num2"

elif [ "$choice" = "2" ]; then
  echo "Enter a number: "
  read num1

  echo "Enter another number: "
  read num2

  # Calculate percentage increase/decrease from num1 to num2
  diff=$(echo "$num2 - $num1" | bc)
  if (( $(echo "$diff > 0" | bc -l) )); then
    percent_diff=$(echo "scale=2; ($diff / $num1) * 100" | bc)
    echo "The percentage increase from $num1 to $num2 is $percent_diff%"
  elif (( $(echo "$diff < 0" | bc -l) )); then
    percent_diff=$(echo "scale=2; ($diff / $num1) * 100" | bc)
    echo "The percentage decrease from $num1 to $num2 is $percent_diff%"
  else
    echo "There is no percentage increase or decrease from $num1 to $num2"
  fi

elif [ "$choice" = "3" ]; then
  echo "Enter a bill amount: "
  read bill_amount

  echo "Enter a tip percentage: "
  read tip_percent

  # Calculate tip amount and total bill amount
  tip=$(echo "scale=2; $bill_amount * ($tip_percent / 100)" | bc)
  total=$(echo "scale=2; $bill_amount + $tip" | bc)

  echo "The tip amount is $tip"
  echo "The total bill amount is $total"

elif [ "$choice" = "4" ]; then
  echo "Would you like to increase or decrease?"
  echo "1. Increase"
  echo "2. Decrease"
  read inc_dec_choice

  echo "Enter a number: "
  read num1

  echo "Enter a percentage: "
  read percent

  if [ "$inc_dec_choice" = "1" ]; then
    # Calculate the increased value
    increased_value=$(echo "scale=2; $num1 * (($percent / 100) + 1)" | bc)
    echo "The increase by $percent% is $increased_value"
  elif [ "$inc_dec_choice" = "2" ]; then
    # Calculate the decreased value
    decreased_value=$(echo "scale=2; $num1 * (1 - ($percent / 100))" | bc)
    echo "The decrease by $percent% is $decreased_value"
  else
    echo "Invalid input, please choose 1 or 2."
  fi

else
  echo "Invalid choice, please choose between 1, 2, 3, or 4"
  exit 1
fi