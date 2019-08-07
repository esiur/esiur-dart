class PropertyValue
{
    /// <summary>
    /// Get or set the value.
    /// </summary>
    dynamic value;
    /// <summary>
    /// Get or set date of modification or occurrence.
    /// </summary>
    DateTime date;
    /// <summary>
    /// Get or set property age.
    /// </summary>
    int age;

    /// <summary>
    /// Create an instance of PropertyValue.
    /// </summary>
    /// <param name="value">Value.</param>
    /// <param name="age">Age.</param>
    /// <param name="date">Date.</param>
    PropertyValue(this.value, this.age, this.date);
}
