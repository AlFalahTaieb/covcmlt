#!/bin/bash

# Set up variables
workout_log="workout_log.txt"
current_date=$(date +"%Y-%m-%d")
workout_date=""
exercise=""
workout_type=""
duration=""
distance=""
calories=""
line=""

# Print menu options
function print_menu() {
  echo "1. Log a strength workout"
  echo "2. Log a cardio workout"
  echo "3. View workout history"
  echo "4. Quit"
}

# Log a strength workout
function log_strength_workout() {
  # Prompt user for workout date
  read -p "Enter the date of the workout (YYYY-MM-DD): " workout_date

  # Prompt user for exercise name
  read -p "Enter the name of the exercise: " exercise

  # Prompt user for number of sets, reps, and weight
  read -p "Enter the number of sets: " sets
  read -p "Enter the number of reps: " reps
  read -p "Enter the weight (in pounds): " weight

  # Write log entry to file
  line="$workout_date $exercise $sets sets x $reps reps x $weight lbs"
  echo $line >> $workout_log

  echo "Workout logged successfully."
}

# Log a cardio workout
function log_cardio_workout() {
  # Prompt user for workout date
  read -p "Enter the date of the workout (YYYY-MM-DD): " workout_date

  # Prompt user for exercise name
  read -p "Enter the name of the exercise: " exercise

  # Prompt user for workout type (e.g. cross trainer, treadmill, etc.)
  read -p "Enter the type of cardio workout (e.g. cross trainer, treadmill, etc.): " workout_type

  # Prompt user for duration and distance
  read -p "Enter the duration of the workout (in minutes): " duration
  read -p "Enter the distance covered (in Km): " distance

  # Prompt user for estimated calories burned
  read -p "Enter the estimated number of calories burned: " calories

  # Write log entry to file
  line="$workout_date $exercise ($workout_type) $duration minutes, $distance Km, $calories calories burned"
  echo $line >> $workout_log

  echo "Workout logged successfully."
}

# View workout history
function view_workout_history() {
  # Print workout history
  echo "Workout history:"
  echo "----------------"
  cat $workout_log
}

# Main loop
while true; do
  # Print menu options and prompt user for choice
  print_menu
  read -p "Enter your choice: " choice

  # Handle user choice
  case $choice in
    1)
      log_strength_workout
      ;;
    2)
      log_cardio_workout
      ;;
    3)
      view_workout_history
      ;;
    4)
      # Quit
      echo "Goodbye!"
      exit
      ;;
    *)
      echo "Invalid choice. Please try again."
      ;;
  esac

  echo ""
done
